import os

# Settings are read at import time, so these have to land before anything
# under app.* is imported. The suite never opens this database (every test runs
# against in-memory SQLite), but Settings still requires the fields to exist,
# and without them `pytest` fails on a fresh clone that has no .env yet.
os.environ.setdefault("DATABASE_URL", "postgresql+psycopg://florg:florg@localhost:5432/florg")
os.environ.setdefault("SECRET_KEY", "chave-de-teste-com-mais-de-32-bytes-para-o-pytest")
os.environ.setdefault("ENVIRONMENT", "dev")

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db.base import Base
from app.db import base_all_models  # noqa: F401  registra todos os modelos
from app.db.seed import seed_default_categories
from app.db.session import get_db
from app.main import app


@pytest.fixture
def db_session():
    """In-memory SQLite database, isolated and recreated for each test.

    SQLite is deliberate here: the suite runs without Docker or Postgres. The
    models use sqlalchemy.Uuid (dialect-agnostic) precisely for this. StaticPool
    keeps a single connection, otherwise each checkout would see an empty
    database.
    """
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    TestingSession = sessionmaker(autocommit=False, autoflush=False, bind=engine)

    session = TestingSession()
    seed_default_categories(session)
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(engine)
        engine.dispose()


@pytest.fixture
def client(db_session):
    def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db
    # TestClient without "with" on purpose: the lifespan would open a session
    # against the real DATABASE_URL just to seed categories. Seeding already
    # happened in the db_session fixture, against in-memory SQLite.
    yield TestClient(app)
    app.dependency_overrides.clear()


@pytest.fixture
def auth_headers(client):
    """Registers a user and returns a ready-to-use Authorization header."""
    client.post(
        "/auth/register",
        json={"name": "Thomas", "email": "thomas@florg.com.br", "password": "senha-forte-123"},
    )
    response = client.post(
        "/auth/login",
        data={"username": "thomas@florg.com.br", "password": "senha-forte-123"},
    )
    token = response.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def account(client, auth_headers):
    response = client.post(
        "/accounts",
        headers=auth_headers,
        json={"name": "Conta Corrente", "type": "checking", "balance": "1000.00"},
    )
    return response.json()
