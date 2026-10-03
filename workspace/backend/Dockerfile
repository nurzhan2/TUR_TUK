# Бэкенд TUR TUK: API + веб-админка. Один процесс uvicorn — WebSocket-реестры
# чата и трекинга живут в памяти, поэтому воркер ровно один (для 50+ заказов
# в день хватает с запасом; больше — Redis pub/sub, см. docs/DECISIONS.md).
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY alembic.ini .
COPY alembic ./alembic
COPY app ./app

RUN useradd --create-home --uid 1000 app \
    && mkdir -p /app/media \
    && chown -R app:app /app
USER app

EXPOSE 8000

# Миграции при старте: новая версия бэкенда сама доводит схему БД.
# --proxy-headers: за Caddy адрес гостя берётся из X-Forwarded-For —
# на нём держатся лимиты отправки SMS по IP.
CMD ["sh", "-c", "alembic upgrade head && exec uvicorn app.main:app --host 0.0.0.0 --port 8000 --proxy-headers --forwarded-allow-ips='*'"]
