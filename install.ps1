# Установщик Support Bot для Windows
# Запуск: powershell -ExecutionPolicy Bypass -File install.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Support Bot - Установщик" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Проверка Python
Write-Host "[1/5] Проверка Python..." -ForegroundColor Yellow
try {
    $pythonVersion = python --version 2>&1
    Write-Host "✓ Python найден: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Python не найден!" -ForegroundColor Red
    Write-Host "  Установите Python 3.8+ с https://www.python.org/" -ForegroundColor Red
    exit 1
}

# Проверка pip
Write-Host "[2/5] Проверка pip..." -ForegroundColor Yellow
try {
    $pipVersion = pip --version 2>&1
    Write-Host "✓ pip найден: $pipVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ pip не найден!" -ForegroundColor Red
    Write-Host "  Установите pip или переустановите Python" -ForegroundColor Red
    exit 1
}

# Установка зависимостей
Write-Host "[3/5] Установка зависимостей..." -ForegroundColor Yellow
pip install -r requirements.txt
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Ошибка установки зависимостей!" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Зависимости установлены" -ForegroundColor Green

# Создание .env файла
Write-Host "[4/5] Настройка конфигурации..." -ForegroundColor Yellow
if (Test-Path ".env") {
    Write-Host "⚠ Файл .env уже существует" -ForegroundColor Yellow
    $overwrite = Read-Host "  Перезаписать? (y/N)"
    if ($overwrite -ne "y" -and $overwrite -ne "Y") {
        Write-Host "✓ Используется существующий .env" -ForegroundColor Green
    } else {
        Copy-Item ".env.example" ".env" -Force
        Write-Host "✓ Создан новый .env из шаблона" -ForegroundColor Green
    }
} else {
    if (Test-Path ".env.example") {
        Copy-Item ".env.example" ".env"
        Write-Host "✓ Создан .env из шаблона" -ForegroundColor Green
    } else {
        # Создаем базовый .env
        @"
BOT_TOKEN=your_bot_token_here
SUPPORT_CHAT_ID=your_support_chat_id_here
ADMIN_IDS=your_admin_id_here
DB_PATH=bot/bot.db
"@ | Out-File -FilePath ".env" -Encoding UTF8
        Write-Host "✓ Создан базовый .env файл" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Установка завершена!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Следующие шаги:" -ForegroundColor Yellow
Write-Host "1. Откройте файл .env и заполните:" -ForegroundColor White
Write-Host "   - BOT_TOKEN (получите у @BotFather)" -ForegroundColor White
Write-Host "   - SUPPORT_CHAT_ID (ID группы/канала для поддержки)" -ForegroundColor White
Write-Host "   - ADMIN_IDS (ваш Telegram ID, можно несколько через запятую)" -ForegroundColor White
Write-Host ""
Write-Host "2. Запустите бота:" -ForegroundColor White
Write-Host "   python bot.py" -ForegroundColor Cyan
Write-Host ""
Write-Host "   Или через Docker:" -ForegroundColor White
Write-Host "   docker-compose up -d" -ForegroundColor Cyan
Write-Host ""

