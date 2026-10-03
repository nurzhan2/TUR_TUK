# Деплой TUR TUK на VPS

Один сервер: 2 vCPU, 2 ГБ RAM, Ubuntu 22.04/24.04, Docker. Внутри — PostgreSQL,
API с веб-админкой, Caddy (HTTPS сам) и ежедневный бэкап базы.

## 1. Сервер и домен

1. Купить VPS (Timeweb, Selectel, Hetzner — от ~500 ₽/мес).
2. A-запись домена (например `api.turtuk.ru`) → IP сервера.
3. Установить Docker: `curl -fsSL https://get.docker.com | sh`

## 2. Запуск

```bash
git clone https://github.com/nurzhan2/TUR_TUK.git && cd TUR_TUK/workspace/deploy/prod
cp .env.example .env && nano .env          # DOMAIN, DB_PASSWORD, JWT_SECRET_KEY, ключи
mkdir -p secrets                            # сюда firebase.json, когда будет
docker compose up -d --build
docker compose logs -f api                  # миграции и старт
```

Сервер откажется стартовать, если `JWT_SECRET_KEY` пустой или короче 32
символов, — это защита, а не поломка.

## 3. Первый вход и наполнение

```bash
# владелец админки (телефон + пароль от 8 символов)
docker compose exec api python -m app.cli create-owner --phone +79001234567 --password 'длинный-пароль' --name 'Анастасия'
```

Дальше всё в браузере: `https://DOMAIN/admin` → Настройки (логотип, суммы,
контакты, политика), Категории, Товары с фото, Отели (импорт CSV), Промокоды,
Сотрудники (курьеры).

Перенести текущий демо-каталог (30 товаров, фото, промокоды):

```bash
docker compose cp ../../content api:/tmp/content
docker compose cp ../../client_app/assets/content/photos api:/tmp/photos
docker compose exec api python -m app.cli seed-content --content /tmp/content --photos /tmp/photos
```

## 4. Приложения

Сборка с адресом сервера (боевой режим):

```bash
flutter build appbundle --dart-define=DEMO=false --dart-define=API_BASE_URL=https://DOMAIN
```

## 5. Обслуживание

| Задача | Команда |
| --- | --- |
| Обновить версию | `git pull && docker compose up -d --build` |
| Логи | `docker compose logs -f api` |
| Бэкапы | `docker compose exec backup ls -lh /backups` |
| Восстановить бэкап | `gunzip -c файл.sql.gz \| docker compose exec -T db psql -U turtuk turtuk` |
| Скачать бэкап | `docker compose cp backup:/backups ./backups` |

Бэкапы лежат на том же сервере — раз в неделю копируйте их к себе или
настройте выгрузку в S3.
