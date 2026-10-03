from pathlib import Path

from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
from fastapi.staticfiles import StaticFiles

from app.api.admin import router as admin_router
from app.api.app_config import router as app_config_router
from app.api.auth import router as auth_router
from app.api.cart import router as cart_router
from app.api.catalog import router as catalog_router
from app.api.health import router as health_router
from app.api.orders import router as orders_router
from app.api.payments import router as payments_router
from app.api.promo import router as promo_router
from app.core.config import get_settings
from app.routers.chat import router as chat_router
from app.routers.tracking import router as tracking_router
from app.web.admin import router as admin_web_router
from app.web.deps import AdminAuthRequired
from app.web.hotels import router as admin_hotels_web_router
from app.web.products import router as admin_products_web_router
from app.web.promo import router as admin_promo_web_router
from app.web.settings import router as admin_settings_web_router
from app.web.staff import router as admin_staff_web_router

settings = get_settings()

app = FastAPI(title=settings.app_name)

# Web-сборки приложений (демо, PWA) ходят в API из браузера с другого домена.
# Авторизация — Bearer-заголовок, не cookie, поэтому credentials не нужны.
_origins = [o.strip() for o in settings.cors_origins.split(",") if o.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=_origins or ["*"],
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["ETag"],
)

# Картинки из локального хранилища (пока не настроен S3, см. app/services/storage.py).
_media = Path(settings.media_dir)
_media.mkdir(parents=True, exist_ok=True)
app.mount("/media", StaticFiles(directory=str(_media)), name="media")

app.include_router(health_router)
app.include_router(app_config_router)
app.include_router(auth_router)
app.include_router(admin_router)
app.include_router(admin_web_router)
app.include_router(admin_products_web_router)
app.include_router(admin_hotels_web_router)
app.include_router(admin_promo_web_router)
app.include_router(admin_settings_web_router)
app.include_router(admin_staff_web_router)
app.include_router(orders_router)
app.include_router(catalog_router)
app.include_router(cart_router)
app.include_router(promo_router)
app.include_router(payments_router)
app.include_router(chat_router)
app.include_router(tracking_router)


@app.get("/", include_in_schema=False)
async def root() -> RedirectResponse:
    return RedirectResponse(url="/admin/")


@app.exception_handler(AdminAuthRequired)
async def _admin_auth_required(request: Request, exc: AdminAuthRequired) -> RedirectResponse:
    """Страница админки без входа ведёт на форму логина, а не отдаёт JSON 401."""
    target = "/admin/login"
    if request.url.path not in ("/admin", "/admin/"):
        target += f"?next={request.url.path}"
    response = RedirectResponse(url=target, status_code=status.HTTP_302_FOUND)
    response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, private"
    response.headers["Pragma"] = "no-cache"
    return response
