from pydantic import BaseModel, EmailStr
from uuid import UUID

# ===== AUTH =====

class SignupRequest(BaseModel):
    email: EmailStr
    password: str

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class AuthResponse(BaseModel):
    token: str
    user_id: UUID


# ===== HOLDINGS & ACCOUNT =====

class HoldingResponse(BaseModel):
    symbol: str
    shares: int
    avg_price: float


class AccountResponse(BaseModel):
    account_id: UUID
    cash_balance: float
    holdings: list[HoldingResponse] = []


class DepositRequest(BaseModel):
    amount: float

class TradeRequest(BaseModel):
    symbol: str
    shares: int
    price: float


class BankAccountCreate(BaseModel):
    routing_number: str
    account_number: str


class BankAccountResponse(BaseModel):
    id: UUID
    routing_last4: str
    account_last4: str

from datetime import datetime

class TransactionResponse(BaseModel):
    id: UUID
    type: str
    symbol: str | None = None
    shares: int | None = None
    price: float | None = None
    amount: float
    created_at: datetime
