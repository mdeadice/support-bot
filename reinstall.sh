#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

BOT_DIR="/opt/support-bot"
BACKUP_DIR="/tmp/support-bot-backup-$(date +%Y%m%d_%H%M%S)"

echo -e "${RED}=== ПОЛНАЯ ПЕРЕУСТАНОВКА SUPPORT BOT ===${NC}\n"
echo -e "${YELLOW}ВНИМАНИЕ: Этот скрипт полностью удалит бота и переустановит его заново!${NC}\n"

# Проверка прав root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Ошибка: Скрипт должен быть запущен от root (используйте sudo)${NC}"
    exit 1
fi

# Подтверждение
read -p "Вы уверены? Это удалит все данные бота (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Отменено.${NC}"
    exit 1
fi

echo -e "\n${YELLOW}=== ШАГ 1: Сохранение важных данных ===${NC}"

# Создание временной директории для бэкапа
mkdir -p "$BACKUP_DIR"

# Сохранение БД если есть
if [ -f "$BOT_DIR/bot/bot.db" ]; then
    DB_SIZE=$(stat -f%z "$BOT_DIR/bot/bot.db" 2>/dev/null || stat -c%s "$BOT_DIR/bot/bot.db" 2>/dev/null || echo "0")
    if [ "$DB_SIZE" -gt 0 ]; then
        echo -e "${GREEN}Сохранение базы данных (размер: ${DB_SIZE} байт)...${NC}"
        cp "$BOT_DIR/bot/bot.db" "$BACKUP_DIR/bot.db"
        echo -e "${GREEN}БД сохранена в: $BACKUP_DIR/bot.db${NC}"
    else
        echo -e "${YELLOW}БД существует, но пуста. Пропускаем.${NC}"
    fi
fi

# Сохранение .env если есть
if [ -f "$BOT_DIR/.env" ]; then
    echo -e "${GREEN}Сохранение .env файла...${NC}"
    cp "$BOT_DIR/.env" "$BACKUP_DIR/.env"
    echo -e "${GREEN}.env сохранен в: $BACKUP_DIR/.env${NC}"
fi

# Сохранение резервных копий БД если есть
if ls "$BOT_DIR/bot/bot.db.backup."* 1> /dev/null 2>&1; then
    echo -e "${GREEN}Сохранение резервных копий БД...${NC}"
    mkdir -p "$BACKUP_DIR/backups"
    cp "$BOT_DIR/bot/bot.db.backup."* "$BACKUP_DIR/backups/" 2>/dev/null || true
    echo -e "${GREEN}Резервные копии сохранены.${NC}"
fi

echo -e "\n${YELLOW}=== ШАГ 2: Остановка и удаление контейнеров ===${NC}"

# Переход в директорию если она существует
if [ -d "$BOT_DIR" ]; then
    cd "$BOT_DIR" || exit 1
    
    # Остановка и удаление контейнеров
    if [ -f "docker-compose.yml" ]; then
        echo -e "${YELLOW}Остановка контейнеров...${NC}"
        docker-compose down --remove-orphans 2>/dev/null || docker compose down --remove-orphans 2>/dev/null || true
    fi
fi

# Остановка всех контейнеров с именем support-bot
echo -e "${YELLOW}Остановка всех контейнеров support-bot...${NC}"
docker stop support-bot 2>/dev/null || true
docker rm support-bot 2>/dev/null || true
docker ps -a | grep support-bot | awk '{print $1}' | xargs -r docker stop 2>/dev/null || true
docker ps -a | grep support-bot | awk '{print $1}' | xargs -r docker rm 2>/dev/null || true

echo -e "\n${YELLOW}=== ШАГ 3: Удаление образов ===${NC}"

# Удаление образов
echo -e "${YELLOW}Удаление Docker образов...${NC}"
docker rmi support-bot-support-bot:latest 2>/dev/null || true
docker rmi support-bot_support-bot:latest 2>/dev/null || true
docker images | grep support-bot | awk '{print $3}' | xargs -r docker rmi 2>/dev/null || true
docker image prune -f 2>/dev/null || true

echo -e "\n${YELLOW}=== ШАГ 4: Удаление директории ===${NC}"

# Удаление директории
if [ -d "$BOT_DIR" ]; then
    echo -e "${YELLOW}Удаление директории $BOT_DIR...${NC}"
    rm -rf "$BOT_DIR"
    echo -e "${GREEN}Директория удалена.${NC}"
fi

echo -e "\n${YELLOW}=== ШАГ 5: Чистая установка ===${NC}"

# Запуск скрипта установки
echo -e "${GREEN}Запуск скрипта установки...${NC}"
curl -sSL https://raw.githubusercontent.com/mdeadice/support-bot/main/bot/install.sh | sudo bash

if [ $? -ne 0 ]; then
    echo -e "${RED}Ошибка при установке!${NC}"
    echo -e "${YELLOW}Резервные копии сохранены в: $BACKUP_DIR${NC}"
    exit 1
fi

echo -e "\n${YELLOW}=== ШАГ 6: Восстановление данных ===${NC}"

# Восстановление .env
if [ -f "$BACKUP_DIR/.env" ]; then
    echo -e "${GREEN}Восстановление .env файла...${NC}"
    cp "$BACKUP_DIR/.env" "$BOT_DIR/.env"
    echo -e "${GREEN}.env восстановлен.${NC}"
else
    echo -e "${YELLOW}.env не найден в резервной копии. Создан новый.${NC}"
    echo -e "${YELLOW}Не забудьте отредактировать: nano $BOT_DIR/.env${NC}"
fi

# Восстановление БД
if [ -f "$BACKUP_DIR/bot.db" ]; then
    DB_SIZE=$(stat -f%z "$BACKUP_DIR/bot.db" 2>/dev/null || stat -c%s "$BACKUP_DIR/bot.db" 2>/dev/null || echo "0")
    if [ "$DB_SIZE" -gt 0 ]; then
        echo -e "${GREEN}Восстановление базы данных (размер: ${DB_SIZE} байт)...${NC}"
        cp "$BACKUP_DIR/bot.db" "$BOT_DIR/bot/bot.db"
        chmod 666 "$BOT_DIR/bot/bot.db"
        echo -e "${GREEN}БД восстановлена!${NC}"
    fi
fi

# Восстановление резервных копий
if [ -d "$BACKUP_DIR/backups" ] && [ "$(ls -A $BACKUP_DIR/backups 2>/dev/null)" ]; then
    echo -e "${GREEN}Восстановление резервных копий БД...${NC}"
    cp "$BACKUP_DIR/backups/"* "$BOT_DIR/bot/" 2>/dev/null || true
    echo -e "${GREEN}Резервные копии восстановлены.${NC}"
fi

echo -e "\n${GREEN}=== ПЕРЕУСТАНОВКА ЗАВЕРШЕНА! ===${NC}\n"

echo -e "${YELLOW}Следующие шаги:${NC}"
if [ ! -f "$BACKUP_DIR/.env" ]; then
    echo "1. Отредактируйте файл .env: ${GREEN}nano $BOT_DIR/.env${NC}"
    echo "   Укажите: BOT_TOKEN, SUPPORT_CHAT_ID, ADMIN_IDS"
fi
echo "2. Запустите бота: ${GREEN}cd $BOT_DIR && docker-compose up -d${NC}"
echo "3. Просмотр логов: ${GREEN}cd $BOT_DIR && docker-compose logs -f${NC}\n"

echo -e "${YELLOW}Резервные копии сохранены в: $BACKUP_DIR${NC}"
echo -e "${YELLOW}Вы можете удалить их после проверки работы бота.${NC}\n"

