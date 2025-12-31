from sqlalchemy import Column, Float, Integer, Text, ForeignKey, DateTime, func
from sqlalchemy.orm import relationship
from sqlalchemy.dialects.postgresql import UUID
import uuid
from .database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(Text, unique=True, nullable=False)
    password_hash = Column(Text, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    accounts = relationship("Account", back_populates="user")
    bank_accounts = relationship("BankAccount", back_populates="user", cascade="all, delete-orphan")


class Account(Base):
    __tablename__ = "accounts"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)

    cash_balance = Column(Float, nullable=False, default=0.0)

    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="accounts")
    holdings = relationship("Holding", back_populates="account", cascade="all, delete-orphan")

    transactions = relationship("Transaction", cascade="all, delete-orphan")



class Holding(Base):
    __tablename__ = "holdings"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    account_id = Column(UUID(as_uuid=True), ForeignKey("accounts.id"), nullable=False)

    symbol = Column(Text, nullable=False)
    shares = Column(Integer, nullable=False, default=0)
    avg_price = Column(Float, nullable=False, default=0.0)

    account = relationship("Account", back_populates="holdings")


class BankAccount(Base):
    __tablename__ = "bank_accounts"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)

    routing_number = Column(Text, nullable=False)
    account_number = Column(Text, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="bank_accounts")

class Transaction(Base):
    __tablename__ = "transactions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    account_id = Column(UUID(as_uuid=True), ForeignKey("accounts.id"), nullable=False)

    type = Column(Text, nullable=False)   # "DEPOSIT", "WITHDRAW", "BUY", "SELL"
    symbol = Column(Text)                 # null for deposits/withdrawals
    shares = Column(Integer)              # null for deposits/withdrawals
    price = Column(Float)                 # null for deposits/withdrawals
    amount = Column(Float, nullable=False)  # total +/- amount of the txn

    created_at = Column(DateTime(timezone=True), server_default=func.now())
