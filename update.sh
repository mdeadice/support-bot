#!/bin/bash

set -e

echo "🔄 Обновление Support Bot..."

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

INSTALL_DIR="/opt/support-bot"

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка наличия директории
if [ ! -d "$INSTALL_DIR" ]; then
    error "Бот не установлен. Сначала выполните установку."
    exit 1
fi

cd $INSTALL_DIR

# Создание резервной копии БД
info "Создание резервной копии базы данных..."
if [ -f "bot/bot.db" ]; then
    BACKUP_NAME="bot.db.backup.$(date +%Y%m%d_%H%M%S)"
    cp bot/bot.db "bot/$BACKUP_NAME"
    info "Резервная копия создана: bot/$BACKUP_NAME"
fi

# Остановка контейнера
info "Остановка бота..."
sudo docker-compose down

# Обновление кода
info "Обновление кода из репозитория..."
if [ -d ".git" ]; then
    git pull
else
    warn "Директория не является git репозиторием. Пропускаю обновление кода."
fi

# Пересборка образа
info "Пересборка Docker образа..."
sudo docker-compose build

# Запуск
info "Запуск бота..."
sudo docker-compose up -d

# Проверка статуса
sleep 3
if sudo docker-compose ps | grep -q "Up"; then
    info "✅ Бот успешно обновлен и запущен!"
else
    error "Бот не запустился. Проверьте логи:"
    error "  cd $INSTALL_DIR && sudo docker-compose logs"
    exit 1
fi

