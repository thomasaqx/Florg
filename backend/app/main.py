import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.core.config import get_settings
from app.core.errors import DomainError
from app.core.logging import configure_logging
from app.db import base_all_models  # noqa: F401  garante que os modelos sejam registrados
from app.db.seed import seed_default_categories
from app.db.session import SessionLocal
from app.modules.accounts.router import router as accounts_router
from app.modules.ai.router import router as ai_router
from app.modules.ai.service import build_provider
from app.modules.auth.router import router as auth_router
from app.modules.budgets.router import router as budgets_router
from app.modules.categorization.router import router as categories_router
from app.modules.goals.router import router as goals_router
from app.modules.imports.router import router as imports_router
from app.modules.insights.router import router as insights_router
from app.modules.transactions.router import router as transactions_router

settings = get_settings()
configure_logging(settings.log_level)
logger = logging.getLogger(__name__)

INSECURE_SECRETS = {"troque-esta-chave-em-producao", "changeme", "secret"}
MIN_SECRET_KEY_BYTES = 32


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Failing at boot beats running in production with a publicly known key:
    # anyone could sign a valid JWT and impersonate any user.
    if settings.is_production:
        if settings.secret_key in INSECURE_SECRETS:
            raise RuntimeError(
                "SECRET_KEY ainda e o valor de exemplo. "
                "Defina uma chave real antes de subir em producao."
            )
        # RFC 7518 3.2: an HMAC-SHA256 key must be at least 32 bytes.
        if len(settings.secret_key.encode()) < MIN_SECRET_KEY_BYTES:
            raise RuntimeError(
                f"SECRET_KEY tem menos de {MIN_SECRET_KEY_BYTES} bytes. "
                "Gere uma chave com: python -c \"import secrets; print(secrets.token_urlsafe(48))\""
            )

    # Surfaces an AI_PROVIDER=claude without a key here, not at the first
    # question a user asks FLORA.
    provider = build_provider(settings)
    logger.info("FLORA respondendo pelo provider '%s'.", provider.name)

    db = SessionLocal()
    try:
        seed_default_categories(db)
    finally:
        db.close()
    yield


app = FastAPI(title="FLORG API", version="0.2.0", lifespan=lifespan)


@app.exception_handler(DomainError)
async def handle_domain_error(request: Request, error: DomainError) -> JSONResponse:
    """One shape for every expected failure.

    "detail" is what the app already reads from FastAPI's own errors, so the
    client needs no special case; "code" lets it branch without matching on a
    message written for humans.
    """
    return JSONResponse(
        status_code=error.status_code,
        content={"detail": error.message, "code": error.code},
        headers=error.headers,
    )


@app.exception_handler(Exception)
async def handle_unexpected_error(request: Request, error: Exception) -> JSONResponse:
    # The trace goes to the log; the client gets a message that leaks neither
    # the stack nor the query that failed.
    logger.exception("Erro nao tratado em %s %s", request.method, request.url.path)
    return JSONResponse(
        status_code=500,
        content={"detail": "Erro interno do servidor", "code": "internal_error"},
    )


# Production allows only the listed origins. Dev allows any origin but without
# credentials: "*" combined with credentials is rejected by browsers and hides
# the misconfiguration.
if settings.is_production:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
else:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )

app.include_router(auth_router)
app.include_router(accounts_router)
app.include_router(transactions_router)
app.include_router(categories_router)
app.include_router(insights_router)
app.include_router(imports_router)
app.include_router(goals_router)
app.include_router(budgets_router)
app.include_router(ai_router)


@app.get("/health", tags=["health"])
def health_check():
    return {"status": "ok"}
