from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_name: str = "TUR TUK backend"
    environment: str = "local"

    database_url: str = "postgresql+asyncpg://tur_tuk:tur_tuk@localhost:5433/tur_tuk"

    s3_endpoint_url: str | None = None
    s3_region: str = "ru-central1"
    s3_bucket: str | None = None
    s3_access_key_id: str | None = None
    s3_secret_access_key: str | None = None

    # Локальное хранилище картинок, пока S3 не настроен (см. app/services/storage.py).
    media_dir: str = "media"
    # Публичный адрес API (https://api.example.com) — из него строятся полные
    # ссылки на /media/... для мобильного приложения. Пусто — берётся адрес запроса.
    public_base_url: str | None = None
    # Откуда разрешены запросы браузера (web-сборки приложений). Через запятую; * — все.
    cors_origins: str = "*"

    # dev-дефолт — как у database_url. В проде переопределяется через .env/окружение.
    jwt_secret_key: str = "dev-insecure-secret-change-me-in-production-env"
    jwt_algorithm: str = "HS256"
    jwt_access_token_expire_minutes: int = 30
    jwt_refresh_token_expire_days: int = 30

    sms_code_length: int = 4
    sms_code_ttl_minutes: int = 5

    # "sms_ru" | "twilio" — провайдер из брифа не выбран владельцем окончательно
    sms_provider: str = "sms_ru"
    sms_ru_api_id: str | None = None
    twilio_account_sid: str | None = None
    twilio_auth_token: str | None = None
    twilio_from_number: str | None = None

    # ЮKassa (стек, curated: «Платежи: ЮKassa (СБП + карты РФ)»). shop_id/secret_key
    # не заведены владельцем — режим самостоятельности подставит заглушку.
    yookassa_shop_id: str | None = None
    yookassa_secret_key: str | None = None
    # Мобильное приложение, не сайт — после оплаты ЮKassa делает редирект сюда
    # (deep link обратно в клиентское приложение). Схема не согласована с
    # владельцем явно, это решение по умолчанию для redirect-flow ЮKassa.
    yookassa_return_url: str = "turtuk://payment/return"

    # Приёмочный люк веб-админки: POST /admin/test-login выдаёт cookie-JWT
    # фиксированному тестовому owner'у без SMS. НЕ включать в production —
    # см. .env.example.
    admin_test_login: bool = False

    # Push-уведомления (стек, curated: «Push-уведомления: FCM»), но провайдер
    # из открытого вопроса брифа окончательно не выбран (FCM/RuStore Push/
    # другой) — слой сделан абстракцией именно из-за этой неопределённости
    # (см. app/core/notifications.py). fcm_server_key не заведён владельцем:
    # доступ к консоли Firebase у него пока под вопросом.
    notification_provider: str = "fcm"
    fcm_server_key: str | None = None


@lru_cache
def get_settings() -> Settings:
    return Settings()
