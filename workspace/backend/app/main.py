from fastapi import FastAPI, Request, status
from fastapi.responses import RedirectResponse

from app.api.admin import router as admin_router
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

settings = get_settings()

app = FastAPI(title=settings.app_name)

app.include_router(health_router)
app.include_router(auth_router)
app.include_router(admin_router)
app.include_router(admin_web_router)
app.include_router(admin_products_web_router)
app.include_router(admin_hotels_web_router)
app.include_router(orders_router)
app.include_router(catalog_router)
app.include_router(cart_router)
app.include_router(promo_router)
app.include_router(payments_router)
app.include_router(chat_router)
app.include_router(tracking_router)


@app.exception_handler(AdminAuthRequired)
async def _admin_auth_required(request: Request, exc: AdminAuthRequired) -> RedirectResponse:
    """Веб-админка не отвечает 401/403 на страницы — страницу заменяет форма
    логина, а не JSON-ошибка (см. app/web/deps.py).

    `Cache-Control: no-store` — этот самый редирект и есть ответ на критерий
    приёмки «GET /admin/ без cookie -> 302»; без явного запрета кэширования
    ответ по этому URL кэшируется недетерминированно (зависит от клиента),
    а раз тело/код ответа на `/admin/` целиком зависит от cookie, а не от
    URL, недетерминированное кэширование — риск однажды отдать 200 из кэша
    на запрос без cookie или наоборот."""
    response = RedirectResponse(url="/admin/login", status_code=status.HTTP_302_FOUND)
    response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, private"
    response.headers["Pragma"] = "no-cache"
    return response
