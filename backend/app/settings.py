from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    app_name: str = "lawyer-backend"
    app_base_url: str = "http://localhost:8080"

    database_url: str = "postgresql+psycopg://lawyer:1642017@db:5432/lawyer"

    jwt_secret: str = "1642017"
    jwt_algorithm: str = "HS256"
    access_token_minutes: int = 30
    refresh_token_days: int = 30

    super_admin_email: str = "admin@example.com"
    super_admin_password: str = "1642017"
    # When true, on startup we will force reset the super admin credentials:
    # - ensure a super_admin user exists for super_admin_email
    # - set its password to super_admin_password
    # - optionally disable other super_admin users
    # Use this ONLY temporarily for first-time access, then set it back to false.
    super_admin_force_reset: bool = False
    super_admin_disable_others_on_reset: bool = True

    trial_days_default: int = 30

    # Where case attachments are stored inside the backend container.
    # Mount a persistent host path to this directory in docker-compose.
    upload_dir: str = "/data/uploads"


settings = Settings()

