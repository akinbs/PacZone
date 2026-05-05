from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", case_sensitive=True)

    APP_NAME: str = "PacZone API"
    APP_VERSION: str = "0.1.0"
    APP_ENV: str = "development"
    API_PREFIX: str = "/api/v1"

    CORS_ORIGINS: str = "*"

    DEFAULT_SCAN_SIZE_METERS: int = 150
    MIN_PLAYABILITY_SCORE: int = 60
    PARTIAL_PLAYABILITY_SCORE: int = 45
    MAX_ALLOWED_ACCURACY_METERS: float = 20.0
    MAX_ALLOWED_SPEED_KMH: float = 15.0


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
