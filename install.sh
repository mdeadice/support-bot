#!/bin/bash

set -e

echo "🚀 Установка Support Bot..."

# Проверка на root
if [ "$EUID" -eq 0 ]; then 
   echo "⚠️  Не запускайте скрипт от root. Используйте sudo для отдельных команд."
   exit 1
fi

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Директория установки
INSTALL_DIR="/opt/support-bot"
REPO_URL="https://github.com/mdeadice/support-bot.git"

# Функция для вывода сообщений
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка наличия необходимых команд
check_command() {
    if ! command -v $1 &> /dev/null; then
        error "$1 не установлен. Установите его перед продолжением."
        exit 1
    fi
}

info "Проверка зависимостей..."
check_command git
check_command docker
check_command docker-compose

# Проверка Docker daemon
if ! docker info &> /dev/null; then
    error "Docker daemon не запущен. Запустите Docker перед продолжением."
    exit 1
fi

# Создание директории
info "Создание директории установки..."
sudo mkdir -p $INSTALL_DIR
sudo chown $USER:$USER $INSTALL_DIR

# Клонирование или обновление репозитория
if [ -d "$INSTALL_DIR/.git" ]; then
    info "Обновление репозитория..."
    cd $INSTALL_DIR
    git pull
else
    info "Клонирование репозитория..."
    git clone $REPO_URL $INSTALL_DIR
    cd $INSTALL_DIR
fi

# Создание .env файла если его нет
if [ ! -f "$INSTALL_DIR/.env" ]; then
    info "Создание файла .env..."
    cat > $INSTALL_DIR/.env << EOF
BOT_TOKEN=ваш_токен_от_BotFather
SUPPORT_CHAT_ID=ваш_id_группы_поддержки
ADMIN_IDS=ваш_telegram_id
DB_PATH=/app/bot.db
EOF
    warn "Файл .env создан. Пожалуйста, отредактируйте его перед запуском:"
    warn "  sudo nano $INSTALL_DIR/.env"
    echo ""
    info "После настройки .env запустите:"
    info "  cd $INSTALL_DIR && sudo docker-compose up -d"
    exit 0
fi

# Проверка заполненности .env
if grep -q "ваш_токен_от_BotFather" $INSTALL_DIR/.env || grep -q "ваш_id_группы_поддержки" $INSTALL_DIR/.env; then
    warn "Файл .env содержит значения по умолчанию. Пожалуйста, настройте его:"
    warn "  sudo nano $INSTALL_DIR/.env"
    echo ""
    info "После настройки .env запустите:"
    info "  cd $INSTALL_DIR && sudo docker-compose up -d"
    exit 0
fi

# Остановка существующего контейнера
info "Остановка существующих контейнеров..."
cd $INSTALL_DIR
sudo docker-compose down 2>/dev/null || true

# Сборка и запуск
info "Сборка Docker образа..."
sudo docker-compose build

info "Запуск бота..."
sudo docker-compose up -d

# Проверка статуса
sleep 3
if sudo docker-compose ps | grep -q "Up"; then
    info "✅ Бот успешно установлен и запущен!"
    echo ""
    info "Просмотр логов:"
    info "  cd $INSTALL_DIR && sudo docker-compose logs -f"
    echo ""
    info "Остановка бота:"
    info "  cd $INSTALL_DIR && sudo docker-compose down"
    echo ""
    info "Перезапуск бота:"
    info "  cd $INSTALL_DIR && sudo docker-compose restart"
else
    error "Бот не запустился. Проверьте логи:"
    error "  cd $INSTALL_DIR && sudo docker-compose logs"
    exit 1
fi

