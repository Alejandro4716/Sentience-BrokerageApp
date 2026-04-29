from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
import os
from urllib.parse import quote_plus

def railway_database_url() -> str | None:
    host = os.environ.get("PGHOST")
    user = os.environ.get("PGUSER")
    password = os.environ.get("PGPASSWORD")
    database = os.environ.get("PGDATABASE")
    port = os.environ.get("PGPORT", "5432")
    if not all([host, user, password, database]):
        return None
    return (
        f"postgresql+psycopg2://{quote_plus(user)}:{quote_plus(password)}"
        f"@{host}:{port}/{database}"
    )

def get_database_url() -> str:
    raw = os.environ.get("DATABASE_URL") or os.environ.get("DATABASE_PRIVATE_URL") or ""
    if raw.startswith("postgres://"):
        return raw.replace("postgres://", "postgresql+psycopg2://", 1)
    if raw.startswith("postgresql://"):
        return raw.replace("postgresql://", "postgresql+psycopg2://", 1)
    if raw.startswith("postgresql+psycopg2://"):
        return raw
    return railway_database_url() or "postgresql+psycopg2://postgres:postgres@db:5432/sentience"

DATABASE_URL = get_database_url()

engine = create_engine(DATABASE_URL, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)
Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
