from functools import lru_cache

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str
    secret_key: str
    access_token_expire_minutes: int = 60
    algorithm: str = "HS256"

    # "dev" opens up CORS for local development; "prod" accepts only the
    # origins listed in cors_origins.
    environment: str = "dev"
    cors_origins: list[str] = []
    log_level: str = "INFO"

    # --- FLORA AI ---------------------------------------------------------
    # "auto" uses Claude when a key is configured and the offline provider
    # otherwise, so a clone with no key still has a working chat. "mock" and
    # "claude" force one of them; "claude" without a key fails at boot rather
    # than at the user's first question.
    ai_provider: str = "auto"
    # Never hardcoded and never sent to the app: the key lives only here, and
    # Flutter talks to /ai/chat, never to api.anthropic.com.
    anthropic_api_key: str | None = None
    anthropic_model: str = "claude-sonnet-5"
    anthropic_max_tokens: int = 1024
    anthropic_timeout_seconds: float = 30.0

    @field_validator("cors_origins", mode="before")
    @classmethod
    def _split_origins(cls, value: object) -> object:
        # Allows declaring it in .env as a comma-separated list.
        if isinstance(value, str):
            return [item.strip() for item in value.split(",") if item.strip()]
        return value

    @field_validator("anthropic_api_key", mode="before")
    @classmethod
    def _blank_key_is_absent(cls, value: object) -> object:
        # ANTHROPIC_API_KEY= in a .env should mean "not configured", not "".
        if isinstance(value, str) and not value.strip():
            return None
        return value

    @field_validator("ai_provider")
    @classmethod
    def _known_provider(cls, value: str) -> str:
        normalized = value.strip().lower()
        allowed = {"auto", "mock", "claude"}
        if normalized not in allowed:
            raise ValueError(f"AI_PROVIDER deve ser um de {sorted(allowed)}")
        return normalized

    @property
    def is_production(self) -> bool:
        return self.environment.lower() in {"prod", "production"}

    @property
    def has_anthropic_key(self) -> bool:
        return bool(self.anthropic_api_key)


@lru_cache
def get_settings() -> Settings:
    return Settings()
