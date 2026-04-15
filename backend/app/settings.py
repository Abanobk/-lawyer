from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    app_name: str = "lawyer-backend"
    app_base_url: str = "http://localhost:8080"

    database_url: str = "postgresql+psycopg://lawyer:lawyer@db:5432/lawyer"

    jwt_secret: str = "dev-secret-change-me"
    jwt_algorithm: str = "HS256"
    access_token_minutes: int = 30
    refresh_token_days: int = 30

    super_admin_email: str = "admin@example.com"
    super_admin_password: str = "admin12345"

    trial_days_default: int = 30


settings = Settings()

