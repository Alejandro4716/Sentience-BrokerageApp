from fastapi import FastAPI, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import urlopen
import json
import os

from .database import Base, engine, get_db
from .models import User, Account, Holding, BankAccount, Transaction
from .schemas import SignupRequest, LoginRequest, AuthResponse, AccountResponse, DepositRequest, HoldingResponse, TradeRequest, BankAccountCreate, BankAccountResponse, TransactionResponse
from .auth import hash_password, verify_password, create_token, decode_token
from uuid import UUID
from decimal import Decimal


# Create DB tables
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Sentience Backend")

def allowed_origins():
    defaults = [
        "http://127.0.0.1:5173",
        "http://localhost:5173",
        "http://127.0.0.1:5500",
        "http://localhost:5500",
        "http://127.0.0.1:8001",
        "http://localhost:8001",
        "https://alejandro4716.github.io",
    ]
    extra = os.environ.get("FRONTEND_ORIGINS", "")
    return defaults + [origin.strip().rstrip("/") for origin in extra.split(",") if origin.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins(),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

FINNHUB_API_KEY = os.environ.get("FINNHUB_API_KEY", "")

def finnhub_get(path: str, params: dict):
    if not FINNHUB_API_KEY:
        raise HTTPException(status_code=503, detail="FINNHUB_API_KEY is not configured")

    query = urlencode({**params, "token": FINNHUB_API_KEY})
    url = f"https://finnhub.io/api/v1/{path}?{query}"
    try:
        with urlopen(url, timeout=10) as response:
            return json.loads(response.read().decode("utf-8"))
    except HTTPError as exc:
        detail = exc.read().decode("utf-8") or "Finnhub request failed"
        raise HTTPException(status_code=exc.code, detail=detail)
    except URLError as exc:
        raise HTTPException(status_code=502, detail=str(exc.reason))

# ===== AUTH MIDDLEWARE =====
bearer = HTTPBearer()

def build_account_response(acct: Account, db: Session) -> AccountResponse:
    holdings = (
        db.query(Holding)
        .filter(Holding.account_id == acct.id)
        .all()
    )
    return AccountResponse(
        account_id=acct.id,
        cash_balance=float(acct.cash_balance or 0.0),
        holdings=[
            HoldingResponse(
                symbol=h.symbol,
                shares=h.shares,
                avg_price=float(h.avg_price or 0.0),
            )
            for h in holdings
        ],
    )

def user_has_bank_account(user: User, db: Session) -> bool:
    count = (
        db.query(BankAccount)
        .filter(BankAccount.user_id == user.id)
        .count()
    )
    return count > 0



def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(bearer),
                     db: Session = Depends(get_db)):
    token = credentials.credentials
    try:
        payload = decode_token(token)
        user_id = UUID(payload["sub"])
    except:
        raise HTTPException(status_code=401, detail="Invalid token")
    
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    return user

# ===== ROUTES =====

@app.get("/")
def root():
    return {"message": "Backend is running!"}


@app.get("/market/quote")
def market_quote(symbol: str = Query(..., min_length=1)):
    return finnhub_get("quote", {"symbol": symbol.upper()})


@app.get("/market/candles")
def market_candles(
    symbol: str = Query(..., min_length=1),
    resolution: str = Query(..., min_length=1),
    from_time: int = Query(...),
    to: int = Query(...),
):
    return finnhub_get(
        "stock/candle",
        {
            "symbol": symbol.upper(),
            "resolution": resolution,
            "from": from_time,
            "to": to,
        },
    )

# SIGNUP
@app.post("/auth/signup", response_model=AuthResponse)
def signup(data: SignupRequest, db: Session = Depends(get_db)):
    # check if email in use
    if db.query(User).filter(User.email == data.email).first():
        raise HTTPException(status_code=400, detail="Email already registered")

    # create user
    user = User(email=data.email, password_hash=hash_password(data.password))
    db.add(user)
    db.commit()
    db.refresh(user)

    # create account
    acct = Account(user_id=user.id, cash_balance=0)
    db.add(acct)
    db.commit()

    token = create_token(user.id)
    return AuthResponse(token=token, user_id=user.id)

# LOGIN
@app.post("/auth/login", response_model=AuthResponse)
def login(data: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == data.email).first()
    if not user or not verify_password(data.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    token = create_token(user.id)
    return AuthResponse(token=token, user_id=user.id)


@app.post("/bank-accounts", response_model=BankAccountResponse)
def link_bank_account(
    data: BankAccountCreate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    routing = data.routing_number.strip()
    account = data.account_number.strip()

    if not routing or not account:
        raise HTTPException(status_code=400, detail="Routing and account numbers are required")

    bank = BankAccount(
        user_id=user.id,
        routing_number=routing,
        account_number=account,
    )
    db.add(bank)
    db.commit()
    db.refresh(bank)

    # Only expose last 4 digits to client
    return BankAccountResponse(
        id=bank.id,
        routing_last4=routing[-4:],
        account_last4=account[-4:],
    )


@app.get("/bank-accounts", response_model=list[BankAccountResponse])
def list_bank_accounts(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    banks = (
        db.query(BankAccount)
        .filter(BankAccount.user_id == user.id)
        .all()
    )
    return [
        BankAccountResponse(
            id=b.id,
            routing_last4=b.routing_number[-4:],
            account_last4=b.account_number[-4:],
        )
        for b in banks
    ]



# GET ACCOUNT INFO
@app.get("/account", response_model=AccountResponse)
def get_account(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    acct = db.query(Account).filter(Account.user_id == user.id).first()
    if not acct:
        acct = Account(user_id=user.id, cash_balance=0.0)
        db.add(acct)
        db.commit()
        db.refresh(acct)

    return build_account_response(acct, db)





@app.post("/deposit", response_model=AccountResponse)
def deposit_money(
    data: DepositRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if data.amount <= 0:
        raise HTTPException(status_code=400, detail="Deposit amount must be > 0")

    if not user_has_bank_account(user, db):
        raise HTTPException(status_code=400, detail="No linked bank account")

    acct = db.query(Account).filter(Account.user_id == user.id).first()
    if not acct:
        acct = Account(user_id=user.id, cash_balance=0.0)
        db.add(acct)
        db.commit()
        db.refresh(acct)

    deposit_amt = float(Decimal(str(data.amount)))

    acct.cash_balance = (acct.cash_balance or 0.0) + deposit_amt

    db.add(Transaction(
        account_id=acct.id,
        type="DEPOSIT",
        amount=deposit_amt
    ))


    db.commit()
    db.refresh(acct)

    return build_account_response(acct, db)


@app.post("/withdraw", response_model=AccountResponse)
def withdraw_money(
    data: DepositRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if data.amount <= 0:
        raise HTTPException(status_code=400, detail="Withdraw amount must be > 0")

    if not user_has_bank_account(user, db):
        raise HTTPException(status_code=400, detail="No linked bank account")

    acct = db.query(Account).filter(Account.user_id == user.id).first()
    if not acct:
        raise HTTPException(status_code=400, detail="No account found")

    withdraw_amt = float(Decimal(str(data.amount)))

    # IMPORTANT: withdrawals should only be allowed from available funds
    if (acct.cash_balance or 0.0) < withdraw_amt:
        raise HTTPException(status_code=400, detail="Insufficient available funds")

    acct.cash_balance = (acct.cash_balance or 0.0) - withdraw_amt

    db.add(Transaction(
        account_id=acct.id,
        type="WITHDRAW",
        amount=-withdraw_amt
    ))


    db.commit()
    db.refresh(acct)

    # money "disappears" here 😭
    return build_account_response(acct, db)



@app.post("/trade/buy", response_model=AccountResponse)
def buy_stock(
    data: TradeRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if data.shares <= 0 or data.price <= 0:
        raise HTTPException(status_code=400, detail="Shares and price must be > 0")

    if not user_has_bank_account(user, db):
        raise HTTPException(status_code=400, detail="No linked bank account")
    # Get or create account
    acct = db.query(Account).filter(Account.user_id == user.id).first()
    if not acct:
        acct = Account(user_id=user.id, cash_balance=0.0)
        db.add(acct)
        db.commit()
        db.refresh(acct)

    # Cost of the trade
    cost = float(data.price) * data.shares

    # Check funds
    if (acct.cash_balance or 0.0) < cost:
        raise HTTPException(status_code=400, detail="Insufficient funds")

    # Deduct cash
    acct.cash_balance = (acct.cash_balance or 0.0) - cost

    # Normalize symbol (e.g., "nvda" -> "NVDA")
    symbol = data.symbol.upper()

    # Find existing holding if any
    holding = (
        db.query(Holding)
        .filter(Holding.account_id == acct.id, Holding.symbol == symbol)
        .first()
    )

    if holding:
        # Recalculate average price
        old_shares = holding.shares
        old_avg = holding.avg_price or 0.0
        new_shares = old_shares + data.shares
        new_avg = ((old_avg * old_shares) + (data.price * data.shares)) / new_shares

        holding.shares = new_shares
        holding.avg_price = float(new_avg)
    else:
        # Create new holding
        holding = Holding(
            account_id=acct.id,
            symbol=symbol,
            shares=data.shares,
            avg_price=float(data.price),
        )
        db.add(holding)

    db.add(Transaction(
        account_id=acct.id,
        type="BUY",
        symbol=symbol,
        shares=data.shares,
        price=float(data.price),
        amount=-cost
    ))


    db.commit()
    db.refresh(acct)

    return build_account_response(acct, db)




@app.post("/trade/sell", response_model=AccountResponse)
def sell_stock(
    data: TradeRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if data.shares <= 0 or data.price <= 0:
        raise HTTPException(status_code=400, detail="Shares and price must be > 0")

    if not user_has_bank_account(user, db):
        raise HTTPException(status_code=400, detail="No linked bank account")

    # Get or create account
    acct = db.query(Account).filter(Account.user_id == user.id).first()
    if not acct:
        raise HTTPException(status_code=400, detail="No account found")

    symbol = data.symbol.upper()

    # Find existing holding
    holding = (
        db.query(Holding)
        .filter(Holding.account_id == acct.id, Holding.symbol == symbol)
        .first()
    )

    if not holding or holding.shares < data.shares:
        raise HTTPException(status_code=400, detail="Not enough shares to sell")

    # Proceeds from the sale
    proceeds = float(data.price) * data.shares

    # Update holding
    holding.shares -= data.shares
    if holding.shares == 0:
        db.delete(holding)

    # Credit cash
    acct.cash_balance = (acct.cash_balance or 0.0) + proceeds

    db.add(Transaction(
        account_id=acct.id,
        type="SELL",
        symbol=symbol,
        shares=data.shares,
        price=float(data.price),
        amount=proceeds
    ))


    db.commit()
    db.refresh(acct)

    return build_account_response(acct, db)



@app.get("/transactions", response_model=list[TransactionResponse])
def list_transactions(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    acct = db.query(Account).filter(Account.user_id == user.id).first()
    if not acct:
        raise HTTPException(status_code=400, detail="No account found")

    txns = (
        db.query(Transaction)
        .filter(Transaction.account_id == acct.id)
        .order_by(Transaction.created_at.desc())
        .limit(200)
        .all()
    )

    return [
        TransactionResponse(
            id=t.id,
            type=t.type,
            symbol=t.symbol,
            shares=t.shares,
            price=t.price,
            amount=float(t.amount),
            created_at=t.created_at,
        )
        for t in txns
    ]
