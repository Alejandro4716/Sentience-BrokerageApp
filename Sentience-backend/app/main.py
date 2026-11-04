from fastapi import FastAPI, Depends, HTTPException, Query
from sqlalchemy import text
from sqlalchemy.orm import Session
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from apscheduler.schedulers.background import BackgroundScheduler
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo
import json
import logging
import os

from .database import Base, SessionLocal, engine, get_db
from .models import User, Account, Holding, BankAccount, Transaction, PortfolioSnapshot
from .schemas import SignupRequest, LoginRequest, AuthResponse, AccountResponse, DepositRequest, HoldingResponse, TradeRequest, BankAccountCreate, BankAccountResponse, TransactionResponse, PortfolioSnapshotRequest, PortfolioSnapshotResponse
from .auth import hash_password, verify_password, create_token, decode_token
from uuid import UUID
from decimal import Decimal


# Create DB tables
Base.metadata.create_all(bind=engine)

if engine.dialect.name == "postgresql":
    with engine.begin() as connection:
        connection.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS first_name TEXT NOT NULL DEFAULT ''"))
        connection.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS last_name TEXT NOT NULL DEFAULT ''"))
        connection.execute(text("ALTER TABLE portfolio_snapshots ADD COLUMN IF NOT EXISTS snapshot_type TEXT NOT NULL DEFAULT 'intraday'"))
        connection.execute(text("ALTER TABLE portfolio_snapshots ADD COLUMN IF NOT EXISTS snapshot_date DATE"))
        connection.execute(text("CREATE UNIQUE INDEX IF NOT EXISTS uq_portfolio_snapshot_account_type_date ON portfolio_snapshots (account_id, snapshot_type, snapshot_date)"))

app = FastAPI(title="Sentience Backend")
logger = logging.getLogger(__name__)
MARKET_TIMEZONE = ZoneInfo("America/New_York")
market_close_scheduler: BackgroundScheduler | None = None

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


def snapshot_response(snapshot: PortfolioSnapshot) -> PortfolioSnapshotResponse:
    return PortfolioSnapshotResponse(
        id=snapshot.id,
        cash_balance=float(snapshot.cash_balance),
        holdings_value=float(snapshot.holdings_value),
        total_value=float(snapshot.total_value),
        snapshot_type=snapshot.snapshot_type,
        created_at=snapshot.created_at,
    )


def capture_market_close_snapshots(snapshot_date=None):
    market_date = snapshot_date or datetime.now(MARKET_TIMEZONE).date()
    db = SessionLocal()
    try:
        market_quote = finnhub_get("quote", {"symbol": "SPY"})
        market_timestamp = int(market_quote.get("t") or 0)
        if market_timestamp <= 0:
            logger.warning("Skipping market-close snapshots: SPY quote has no timestamp")
            return 0
        quote_date = datetime.fromtimestamp(market_timestamp, timezone.utc).astimezone(MARKET_TIMEZONE).date()
        if quote_date != market_date:
            logger.info("Skipping market-close snapshots for %s: market was closed", market_date)
            return 0

        holdings = db.query(Holding).all()
        symbols = sorted({holding.symbol for holding in holdings})
        prices = {"SPY": float(market_quote.get("c") or 0.0)}
        for symbol in symbols:
            if symbol == "SPY":
                continue
            try:
                quote = finnhub_get("quote", {"symbol": symbol})
                quote_timestamp = int(quote.get("t") or 0)
                symbol_date = datetime.fromtimestamp(quote_timestamp, timezone.utc).astimezone(MARKET_TIMEZONE).date() if quote_timestamp else None
                price = float(quote.get("c") or 0.0)
                if symbol_date == market_date and price > 0:
                    prices[symbol] = price
            except HTTPException as exc:
                logger.warning("Close quote failed for %s: %s", symbol, exc.detail)

        holdings_by_account = {}
        for holding in holdings:
            holdings_by_account.setdefault(holding.account_id, []).append(holding)

        captured = 0
        for account in db.query(Account).all():
            account_holdings = holdings_by_account.get(account.id, [])
            if any(holding.symbol not in prices for holding in account_holdings):
                logger.warning("Skipping close snapshot for account %s due to missing quotes", account.id)
                continue
            holdings_value = sum(prices[holding.symbol] * holding.shares for holding in account_holdings)
            cash_balance = float(account.cash_balance or 0.0)
            snapshot = (
                db.query(PortfolioSnapshot)
                .filter(
                    PortfolioSnapshot.account_id == account.id,
                    PortfolioSnapshot.snapshot_type == "close",
                    PortfolioSnapshot.snapshot_date == market_date,
                )
                .first()
            )
            if snapshot:
                snapshot.cash_balance = cash_balance
                snapshot.holdings_value = holdings_value
                snapshot.total_value = cash_balance + holdings_value
            else:
                db.add(PortfolioSnapshot(
                    account_id=account.id,
                    cash_balance=cash_balance,
                    holdings_value=holdings_value,
                    total_value=cash_balance + holdings_value,
                    snapshot_type="close",
                    snapshot_date=market_date,
                ))
            captured += 1

        db.commit()
        logger.info("Captured %s market-close portfolio snapshots for %s", captured, market_date)
        return captured
    except Exception:
        db.rollback()
        logger.exception("Market-close portfolio snapshot job failed")
        return 0
    finally:
        db.close()


@app.on_event("startup")
def start_market_close_scheduler():
    global market_close_scheduler
    enabled = os.environ.get("ENABLE_MARKET_CLOSE_SNAPSHOTS", "true").lower() not in {"0", "false", "no"}
    if not enabled or market_close_scheduler:
        return
    market_close_scheduler = BackgroundScheduler(timezone=MARKET_TIMEZONE)
    market_close_scheduler.add_job(
        capture_market_close_snapshots,
        "cron",
        day_of_week="mon-fri",
        hour=16,
        minute=10,
        id="market-close-portfolio-snapshots",
        replace_existing=True,
        coalesce=True,
        misfire_grace_time=21600,
    )
    market_close_scheduler.start()

    now = datetime.now(MARKET_TIMEZONE)
    if now.weekday() < 5 and (now.hour, now.minute) >= (16, 10):
        market_close_scheduler.add_job(
            capture_market_close_snapshots,
            "date",
            run_date=now + timedelta(seconds=2),
            args=[now.date()],
            id="market-close-portfolio-snapshots-catchup",
            replace_existing=True,
        )


@app.on_event("shutdown")
def stop_market_close_scheduler():
    global market_close_scheduler
    if market_close_scheduler:
        market_close_scheduler.shutdown(wait=False)
        market_close_scheduler = None

def yahoo_range_and_interval(resolution: str, from_time: int, to: int):
    days = max(1, int((to - from_time) / 86400))
    if resolution in {"1", "5", "15", "30", "60"} and days <= 7:
        return "5d", f"{resolution}m"
    if days <= 7:
        return "5d", "1d"
    if days <= 35:
        return "1mo", "1d"
    if days <= 100:
        return "3mo", "1d"
    if days <= 370:
        return "1y", "1wk"
    return "5y", "1mo"

def yahoo_candles(symbol: str, resolution: str, from_time: int, to: int):
    chart_range, interval = yahoo_range_and_interval(resolution, from_time, to)
    query = urlencode({"range": chart_range, "interval": interval})
    url = f"https://query1.finance.yahoo.com/v8/finance/chart/{symbol.upper()}?{query}"
    request = Request(url, headers={"User-Agent": "Mozilla/5.0"})
    try:
        with urlopen(request, timeout=10) as response:
            data = json.loads(response.read().decode("utf-8"))
    except HTTPError as exc:
        detail = exc.read().decode("utf-8") or "Yahoo chart request failed"
        raise HTTPException(status_code=exc.code, detail=detail)
    except URLError as exc:
        raise HTTPException(status_code=502, detail=str(exc.reason))

    result = (data.get("chart", {}).get("result") or [None])[0]
    if not result:
        raise HTTPException(status_code=404, detail="No chart data available")

    timestamps = result.get("timestamp") or []
    quote = ((result.get("indicators") or {}).get("quote") or [{}])[0]
    closes = quote.get("close") or []
    opens = quote.get("open") or []
    highs = quote.get("high") or []
    lows = quote.get("low") or []
    volumes = quote.get("volume") or []

    rows = [
        (t, opens[i], highs[i], lows[i], closes[i], volumes[i] if i < len(volumes) else 0)
        for i, t in enumerate(timestamps)
        if i < len(closes) and closes[i] is not None and from_time <= t <= to
    ]
    if len(rows) < 2:
        rows = [
            (t, opens[i], highs[i], lows[i], closes[i], volumes[i] if i < len(volumes) else 0)
            for i, t in enumerate(timestamps)
            if i < len(closes) and closes[i] is not None
        ]

    return {
        "s": "ok" if rows else "no_data",
        "t": [row[0] for row in rows],
        "o": [row[1] for row in rows],
        "h": [row[2] for row in rows],
        "l": [row[3] for row in rows],
        "c": [row[4] for row in rows],
        "v": [row[5] for row in rows],
    }

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
    try:
        return finnhub_get(
            "stock/candle",
            {
                "symbol": symbol.upper(),
                "resolution": resolution,
                "from": from_time,
                "to": to,
            },
        )
    except HTTPException as exc:
        if exc.status_code not in {401, 403, 429}:
            raise
        return yahoo_candles(symbol, resolution, from_time, to)

# SIGNUP
@app.post("/auth/signup", response_model=AuthResponse)
def signup(data: SignupRequest, db: Session = Depends(get_db)):
    first_name = data.first_name.strip()
    last_name = data.last_name.strip()
    if not first_name or not last_name:
        raise HTTPException(status_code=400, detail="First and last name are required")

    # check if email in use
    if db.query(User).filter(User.email == data.email).first():
        raise HTTPException(status_code=400, detail="Email already registered")

    # create user
    user = User(
        first_name=first_name,
        last_name=last_name,
        email=data.email,
        password_hash=hash_password(data.password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    # create account
    acct = Account(user_id=user.id, cash_balance=0)
    db.add(acct)
    db.commit()

    token = create_token(user.id)
    return AuthResponse(
        token=token,
        user_id=user.id,
        first_name=user.first_name,
        last_name=user.last_name,
    )

# LOGIN
@app.post("/auth/login", response_model=AuthResponse)
def login(data: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == data.email).first()
    if not user or not verify_password(data.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    token = create_token(user.id)
    return AuthResponse(
        token=token,
        user_id=user.id,
        first_name=user.first_name or "",
        last_name=user.last_name or "",
    )


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


@app.post("/portfolio/snapshots", response_model=PortfolioSnapshotResponse)
def record_portfolio_snapshot(
    data: PortfolioSnapshotRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if data.holdings_value < 0:
        raise HTTPException(status_code=400, detail="Holdings value cannot be negative")

    acct = db.query(Account).filter(Account.user_id == user.id).first()
    if not acct:
        raise HTTPException(status_code=400, detail="No account found")

    cash_balance = float(acct.cash_balance or 0.0)
    holdings_value = float(data.holdings_value)
    total_value = cash_balance + holdings_value
    latest = (
        db.query(PortfolioSnapshot)
        .filter(PortfolioSnapshot.account_id == acct.id)
        .order_by(PortfolioSnapshot.created_at.desc())
        .first()
    )

    latest_at = latest.created_at if latest else None
    if latest_at and latest_at.tzinfo is None:
        latest_at = latest_at.replace(tzinfo=timezone.utc)

    if latest and latest_at and datetime.now(timezone.utc) - latest_at <= timedelta(minutes=5):
        latest.cash_balance = cash_balance
        latest.holdings_value = holdings_value
        latest.total_value = total_value
        snapshot = latest
    else:
        snapshot = PortfolioSnapshot(
            account_id=acct.id,
            cash_balance=cash_balance,
            holdings_value=holdings_value,
            total_value=total_value,
        )
        db.add(snapshot)

    db.commit()
    db.refresh(snapshot)
    return snapshot_response(snapshot)


@app.get("/portfolio/history", response_model=list[PortfolioSnapshotResponse])
def portfolio_history(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    acct = db.query(Account).filter(Account.user_id == user.id).first()
    if not acct:
        return []

    snapshots = (
        db.query(PortfolioSnapshot)
        .filter(PortfolioSnapshot.account_id == acct.id)
        .order_by(PortfolioSnapshot.created_at.desc())
        .limit(1000)
        .all()
    )
    snapshots.reverse()
    return [snapshot_response(snapshot) for snapshot in snapshots]





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
