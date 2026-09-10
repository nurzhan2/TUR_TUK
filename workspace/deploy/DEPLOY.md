# Как выложить демо

Сборка: `powershell -ExecutionPolicy Bypass -File workspace\deploy\build_demo.ps1`
Результат — папка `workspace\deploy\dist`:

```
dist/
  index.html      страница-развилка
  client/         приложение клиента   (base href /client/)
  courier/        приложение курьера   (base href /courier/)
```

Это статика, серверная часть не нужна: демо работает на моках
(`--dart-define=DEMO=true`).

## Сначала — посмотреть локально

```powershell
cd C:\dev\TUR_TUK\workspace\deploy\dist
python -m http.server 8080
```

Открыть `http://localhost:8080`. С телефона в той же сети — по IP машины
(`ipconfig` → адрес вида `192.168.х.х:8080`).

## Вариант 1 — Netlify Drop (быстрее всего, ничего настраивать не надо)

1. Открыть https://app.netlify.com/drop
2. Перетащить туда папку `dist` целиком
3. Получить ссылку вида `https://random-name-123.netlify.app`

Аккаунт не обязателен, но без него ссылка живёт сутки. Заведёшь бесплатный —
ссылка постоянная, и там же меняется имя поддомена на что-то вроде
`turtuk-demo.netlify.app`.

Годится, чтобы отправить заказчице сегодня.

## Вариант 2 — свой VPS с nginx

Залить `dist` в `/var/www/turtuk-demo`, конфиг:

```nginx
server {
    listen 80;
    server_name demo.example.ru;
    root /var/www/turtuk-demo;
    index index.html;

    # Flutter web — SPA: любой неизвестный путь внутри приложения
    # отдаём его index.html, иначе перезагрузка страницы даст 404.
    location /client/ {
        try_files $uri $uri/ /client/index.html;
    }
    location /courier/ {
        try_files $uri $uri/ /courier/index.html;
    }
    location / {
        try_files $uri $uri/ /index.html;
    }

    # main.dart.js и canvaskit весят прилично — без сжатия первая
    # загрузка на мобильном интернете будет долгой.
    gzip on;
    gzip_types text/plain text/css application/javascript application/json image/svg+xml;
    gzip_min_length 1024;
}
```

Дальше `certbot --nginx -d demo.example.ru` для HTTPS. Без HTTPS iPhone не
даст добавить приложение на домашний экран как standalone.

## Вариант 3 — тот же хостинг, где живёт бэкенд

Если демо-бэкенд уже поднят, `dist` кладётся рядом статикой. Для FastAPI:

```python
from fastapi.staticfiles import StaticFiles
app.mount("/demo", StaticFiles(directory="dist", html=True), name="demo")
```

Тогда сборку надо делать с `--base-href /demo/client/` и `/demo/courier/`
соответственно — иначе приложение будет искать свои файлы в корне домена.

## Вариант 4 — GitHub Pages

**Сейчас недоступен**: аккаунт `nurzhan2` заблокирован, push и Actions не
работают. Когда разблокируют — workflow ниже кладётся в
`.github/workflows/deploy-demo.yml`:

```yaml
name: Deploy demo
on:
  workflow_dispatch:
  push:
    branches: [main]

permissions:
  contents: read
  pages: write
  id-token: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - name: Build client
        working-directory: workspace/client_app
        run: |
          flutter pub get
          flutter build web --release --dart-define=DEMO=true --base-href /TUR_TUK/client/
      - name: Build courier
        working-directory: workspace/courier_app
        run: |
          flutter pub get
          flutter build web --release --dart-define=DEMO=true --base-href /TUR_TUK/courier/
      - name: Assemble
        run: |
          mkdir -p dist/client dist/courier
          cp -r workspace/client_app/build/web/* dist/client/
          cp -r workspace/courier_app/build/web/* dist/courier/
          cp workspace/deploy/landing.html dist/index.html
      - uses: actions/upload-pages-artifact@v3
        with:
          path: dist

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
    steps:
      - uses: actions/deploy-pages@v4
```

Ссылка получится `https://nurzhan2.github.io/TUR_TUK/`. Репозиторий
приватный — Pages из приватного репозитория работают не на всех тарифах,
проверить перед тем, как обещать ссылку заказчице.

## Размер сборки

Клиентское приложение: `main.dart.js` 3,1 МБ, движок отрисовки ~1,5 МБ в
сжатом виде, фото товаров 2,7 МБ подгружаются по мере показа. Первая
загрузка на мобильном интернете — несколько секунд, дальше всё из кеша.
Папка `canvaskit` на диске занимает 36 МБ, но браузер скачивает только одну
свою сборку, а не всю папку.

## Проверить перед отправкой ссылки

- открыть с телефона, а не только с компьютера
- Safari → «Поделиться» → «На экран «Домой»» → запускается без адресной строки
- обе ссылки с развилки открываются
- фото товаров видны, а не серые квадраты
