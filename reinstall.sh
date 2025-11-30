#!/bin/bash

set -e

echo "🔄 Переустановка Support Bot..."

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

INSTALL_DIR="/opt/support-bot"
REPO_URL="https://github.com/mdeadice/support-bot.git"

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Подтверждение
echo ""
warn "⚠️  ВНИМАНИЕ: Это удалит все данные бота, кроме базы данных и .env файла!"
warn "Резервная копия БД и .env будет создана в /tmp/support-bot-backup-XXXXXX/"
echo ""
read -p "Продолжить? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    info "Отменено."
    exit 0
fi

# Создание резервной копии
BACKUP_DIR=$(mktemp -d -t support-bot-backup-XXXXXX)
info "Создание резервной копии в $BACKUP_DIR..."

if [ -d "$INSTALL_DIR" ]; then
    if [ -f "$INSTALL_DIR/bot/bot.db" ]; then
        cp "$INSTALL_DIR/bot/bot.db" "$BACKUP_DIR/bot.db"
        info "База данных скопирована"
    fi
    
    if [ -f "$INSTALL_DIR/.env" ]; then
        cp "$INSTALL_DIR/.env" "$BACKUP_DIR/.env"
        info ".env файл скопирован"
    fi
fi

# Остановка и удаление контейнеров
if [ -d "$INSTALL_DIR" ]; then
    info "Остановка контейнеров..."
    cd $INSTALL_DIR
    sudo docker-compose down 2>/dev/null || true
fi

# Удаление образов
info "Удаление Docker образов..."
sudo docker rmi support-bot-support-bot 2>/dev/null || true

# Удаление директории
if [ -d "$INSTALL_DIR" ]; then
    info "Удаление директории установки..."
    sudo rm -rf $INSTALL_DIR
fi

# Установка заново
info "Выполнение чистой установки..."
sudo mkdir -p $INSTALL_DIR
sudo chown $USER:$USER $INSTALL_DIR
git clone $REPO_URL $INSTALL_DIR
cd $INSTALL_DIR

# Восстановление резервной копии
if [ -f "$BACKUP_DIR/bot.db" ]; then
    info "Восстановление базы данных..."
    mkdir -p bot
    cp "$BACKUP_DIR/bot.db" "bot/bot.db"
fi

if [ -f "$BACKUP_DIR/.env" ]; then
    info "Восстановление .env файла..."
    cp "$BACKUP_DIR/.env" ".env"
else
    # Создание .env если его не было
    cat > .env << EOF
BOT_TOKEN=ваш_токен_от_BotFather
SUPPORT_CHAT_ID=ваш_id_группы_поддержки
ADMIN_IDS=ваш_telegram_id
DB_PATH=/app/bot.db
EOF
    warn "Создан новый .env файл. Настройте его перед запуском."
fi

# Сборка и запуск
info "Сборка Docker образа..."
sudo docker-compose build

if [ -f ".env" ] && ! grep -q "ваш_токен_от_BotFather" .env; then
    info "Запуск бота..."
    sudo docker-compose up -d
    
    sleep 3
    if sudo docker-compose ps | grep -q "Up"; then
        info "✅ Бот успешно переустановлен и запущен!"
    else
        error "Бот не запустился. Проверьте логи:"
        error "  cd $INSTALL_DIR && sudo docker-compose logs"
    fi
else
    warn "Настройте .env файл перед запуском:"
    warn "  sudo nano $INSTALL_DIR/.env"
    warn "Затем запустите:"
    warn "  cd $INSTALL_DIR && sudo docker-compose up -d"
fi

info "Резервная копия сохранена в: $BACKUP_DIR"

