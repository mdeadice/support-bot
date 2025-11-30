#!/bin/bash
# Установщик Support Bot для Linux/Mac
# Запуск: bash install.sh

echo "========================================"
echo "   Support Bot - Установщик"
echo "========================================"
echo ""

# Проверка Python
echo "[1/5] Проверка Python..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version 2>&1)
    echo "✓ Python найден: $PYTHON_VERSION"
    PYTHON_CMD=python3
    PIP_CMD=pip3
elif command -v python &> /dev/null; then
    PYTHON_VERSION=$(python --version 2>&1)
    echo "✓ Python найден: $PYTHON_VERSION"
    PYTHON_CMD=python
    PIP_CMD=pip
else
    echo "✗ Python не найден!"
    echo "  Установите Python 3.8+ с https://www.python.org/"
    exit 1
fi

# Проверка pip
echo "[2/5] Проверка pip..."
if command -v $PIP_CMD &> /dev/null; then
    PIP_VERSION=$($PIP_CMD --version 2>&1)
    echo "✓ pip найден: $PIP_VERSION"
else
    echo "✗ pip не найден!"
    echo "  Установите pip: $PYTHON_CMD -m ensurepip --upgrade"
    exit 1
fi

# Установка зависимостей
echo "[3/5] Установка зависимостей..."
$PIP_CMD install -r requirements.txt
if [ $? -ne 0 ]; then
    echo "✗ Ошибка установки зависимостей!"
    exit 1
fi
echo "✓ Зависимости установлены"

# Создание .env файла
echo "[4/5] Настройка конфигурации..."
if [ -f ".env" ]; then
    echo "⚠ Файл .env уже существует"
    read -p "  Перезаписать? (y/N): " overwrite
    if [ "$overwrite" != "y" ] && [ "$overwrite" != "Y" ]; then
        echo "✓ Используется существующий .env"
    else
        if [ -f ".env.example" ]; then
            cp .env.example .env
            echo "✓ Создан новый .env из шаблона"
        else
            cat > .env << EOF
BOT_TOKEN=your_bot_token_here
SUPPORT_CHAT_ID=your_support_chat_id_here
ADMIN_IDS=your_admin_id_here
DB_PATH=bot/bot.db
EOF
            echo "✓ Создан базовый .env файл"
        fi
    fi
else
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo "✓ Создан .env из шаблона"
    else
        cat > .env << EOF
BOT_TOKEN=your_bot_token_here
SUPPORT_CHAT_ID=your_support_chat_id_here
ADMIN_IDS=your_admin_id_here
DB_PATH=bot/bot.db
EOF
        echo "✓ Создан базовый .env файл"
    fi
fi

# Создание директории для базы данных
echo "[5/5] Создание директорий..."
mkdir -p bot
echo "✓ Директории созданы"

echo ""
echo "========================================"
echo "   Установка завершена!"
echo "========================================"
echo ""
echo "Следующие шаги:"
echo "1. Откройте файл .env и заполните:"
echo "   - BOT_TOKEN (получите у @BotFather)"
echo "   - SUPPORT_CHAT_ID (ID группы/канала для поддержки)"
echo "   - ADMIN_IDS (ваш Telegram ID, можно несколько через запятую)"
echo ""
echo "2. Запустите бота:"
echo "   $PYTHON_CMD bot.py"
echo ""
echo "   Или через Docker:"
echo "   docker-compose up -d"
echo ""

