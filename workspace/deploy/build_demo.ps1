# Сборка демо TUR TUK: два веб-приложения + страница-развилка.
#
# Запуск из любой папки:
#   powershell -ExecutionPolicy Bypass -File workspace\deploy\build_demo.ps1
#
# Результат: workspace\deploy\dist — статика, которую можно положить на
# любой хостинг. Демо-режим включён, бэкенд для работы не нужен.

$ErrorActionPreference = 'Stop'

$deploy    = $PSScriptRoot
$workspace = Split-Path $deploy -Parent
$dist      = Join-Path $deploy 'dist'

function Build-App {
    param(
        [string]$Name,      # папка приложения
        [string]$BaseHref,  # подпапка на хостинге, например /client/
        [string]$OutName    # папка внутри dist
    )

    $appDir = Join-Path $workspace $Name
    Write-Host ""
    Write-Host "=== $Name ===" -ForegroundColor Cyan

    Push-Location $appDir
    try {
        & flutter pub get | Out-Null
        # Ключ DEMO=true — приложение работает на моках, без бэкенда.
        & flutter build web --release --dart-define=DEMO=true --base-href $BaseHref
        if ($LASTEXITCODE -ne 0) { throw "$Name : сборка упала" }
    }
    finally {
        Pop-Location
    }

    $target = Join-Path $dist $OutName
    if (Test-Path $target) { Remove-Item $target -Recurse -Force }
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    Copy-Item (Join-Path $appDir 'build\web\*') $target -Recurse -Force

    $size = (Get-ChildItem $target -Recurse -File | Measure-Object Length -Sum).Sum / 1MB
    Write-Host ("{0}: готово, {1:N1} МБ" -f $Name, $size) -ForegroundColor Green
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'flutter не найден в PATH'
}

New-Item -ItemType Directory -Path $dist -Force | Out-Null

Build-App -Name 'client_app'  -BaseHref '/client/'  -OutName 'client'
Build-App -Name 'courier_app' -BaseHref '/courier/' -OutName 'courier'

Copy-Item (Join-Path $deploy 'landing.html') (Join-Path $dist 'index.html') -Force

$total = (Get-ChildItem $dist -Recurse -File | Measure-Object Length -Sum).Sum / 1MB
Write-Host ""
Write-Host ("Готово: {0}" -f $dist) -ForegroundColor Green
Write-Host ("Общий размер: {0:N1} МБ" -f $total)
Write-Host ""
Write-Host "Посмотреть локально:" -ForegroundColor Yellow
Write-Host "  cd `"$dist`"; python -m http.server 8080"
Write-Host "  затем открыть http://localhost:8080"
