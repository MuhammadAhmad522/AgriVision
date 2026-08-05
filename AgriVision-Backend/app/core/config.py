from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore", case_sensitive=True)

    PROJECT_NAME: str = "AgriVision API"
    ENVIRONMENT: str = "development"
    DATABASE_URL: str = "postgresql://admin:password@db:5432/agrivision"
    REDIS_URL: str = "redis://redis:6379/0"
    ENABLE_TIMESCALEDB: bool = False

    FIREBASE_SERVICE_ACCOUNT_PATH: str = "/app/firebase-credentials.json"
    # Firebase permits 0...60 seconds. Five seconds absorbs normal clock and
    # token-issuance jitter without materially extending token validity.
    FIREBASE_CLOCK_SKEW_SECONDS: int = Field(default=5, ge=0, le=60)
    # Online revocation checks call Identity Toolkit for every authenticated
    # request. Keep routine verification local and bounded by default.
    FIREBASE_CHECK_REVOKED: bool = False
    FIREBASE_VERIFY_TIMEOUT_SECONDS: float = Field(default=8.0, gt=0, le=30)
    MQTT_BROKER: str = "mqtt"
    MQTT_PORT: int = 1883
    MQTT_USERNAME: str | None = None
    MQTT_PASSWORD: str | None = None

    AGROMONITORING_API_KEY: str = ""
    AGRO_FREE_MODE: bool = True
    AGRO_SATELLITE_INTERVAL_HOURS: int = 6
    AGRO_SOIL_INTERVAL_HOURS: int = 6
    AGRO_WEATHER_INTERVAL_HOURS: int = 6
    AGRO_UVI_INTERVAL_HOURS: int = 6
    AGRO_INITIAL_SYNC_TIMEOUT_SECONDS: int = 15
    AGRO_WORKER_SCAN_SECONDS: int = 5 * 60
    AGRO_MAX_CONCURRENCY: int = 2
    AGRO_MEDIA_ROOT: str = "./media/agro"

    GOOGLE_API_KEY: str = ""  # Compatibility fallback for paid Gemini Developer API only.
    GOOGLE_CLOUD_PROJECT: str = ""
    GOOGLE_CLOUD_LOCATION: str = "global"
    GOOGLE_GENAI_USE_VERTEXAI: bool = True
    GOOGLE_AI_MODEL: str = "gemini-2.0-flash"
    VERTEX_SEARCH_DATASTORE: str = ""
    AI_PROMPT_VERSION: str = "agrivision-punjab-v2"
    AI_POLICY_VERSION: str = "guarded-advisory-v1"
    AI_PROVIDER_TIMEOUT_SECONDS: float = Field(default=45.0, gt=0, le=120)
    CHAT_MEDIA_ROOT: str = "./media/chat"
    CHAT_GCS_BUCKET: str = ""
    CHAT_MAX_IMAGES: int = 3
    CHAT_MAX_IMAGE_BYTES: int = 10 * 1024 * 1024
    CHAT_MAX_PIXELS: int = 24_000_000
    CHAT_MAX_DIMENSION: int = 2048
    CHAT_REQUEST_MAX_BYTES: int = 32 * 1024 * 1024
    ACTIVE_FIELD_LIMIT: int = 5
    MAX_REQUEST_BODY_BYTES: int = 1_048_576
    ALLOWED_ORIGINS: str = ""

    @property
    def allowed_origins(self) -> list[str]:
        return [origin.strip() for origin in self.ALLOWED_ORIGINS.split(",") if origin.strip()]

    @property
    def agro_media_path(self) -> Path:
        return Path(self.AGRO_MEDIA_ROOT)

    @property
    def chat_media_path(self) -> Path:
        return Path(self.CHAT_MEDIA_ROOT)


settings = Settings()
