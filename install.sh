#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

BOT_DIR="/opt/support-bot"

echo -e "${GREEN}=== Установка Support Bot ===${NC}\n"

# Проверка прав root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Ошибка: Скрипт должен быть запущен от root (используйте sudo)${NC}"
    exit 1
fi

# Проверка наличия Docker
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Docker не найден. Установка Docker...${NC}"
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sh /tmp/get-docker.sh
    rm /tmp/get-docker.sh
    echo -e "${GREEN}Docker установлен!${NC}\n"
fi

# Проверка наличия docker-compose
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${YELLOW}docker-compose не найден. Установка...${NC}"
    # Для старых версий docker-compose
    if ! command -v docker-compose &> /dev/null; then
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi
    echo -e "${GREEN}docker-compose установлен!${NC}\n"
fi

# Создание директории
echo -e "${GREEN}Создание директории $BOT_DIR...${NC}"
mkdir -p "$BOT_DIR/bot"

# Сохранение существующей БД и .env если есть
if [ -f "$BOT_DIR/bot/bot.db" ]; then
    echo -e "${YELLOW}Обнаружена существующая база данных. Она будет сохранена.${NC}"
fi
if [ -f "$BOT_DIR/.env" ]; then
    echo -e "${YELLOW}Обнаружен существующий .env файл. Он будет сохранен.${NC}"
fi

# Переход в директорию
cd "$BOT_DIR" || exit 1

echo -e "${GREEN}Скачивание файлов с GitHub...${NC}"

# Скачивание файлов
echo -e "Скачивание bot.py..."
curl -sL -o bot/bot.py https://raw.githubusercontent.com/mdeadice/support-bot/main/bot/bot.py || curl -sL -o bot/bot.py https://raw.githubusercontent.com/mdeadice/support-bot/main/bot.py

echo -e "Скачивание docker-compose.yml..."
curl -s -o docker-compose.yml https://raw.githubusercontent.com/mdeadice/support-bot/main/bot/docker-compose.yml || curl -s -o docker-compose.yml https://raw.githubusercontent.com/mdeadice/support-bot/main/docker-compose.yml

echo -e "Скачивание requirements.txt..."
curl -s -o requirements.txt https://raw.githubusercontent.com/mdeadice/support-bot/main/bot/requirements.txt || curl -s -o requirements.txt https://raw.githubusercontent.com/mdeadice/support-bot/main/requirements.txt

echo -e "Скачивание Dockerfile..."
curl -s -o Dockerfile https://raw.githubusercontent.com/mdeadice/support-bot/main/bot/Dockerfile || curl -s -o Dockerfile https://raw.githubusercontent.com/mdeadice/support-bot/main/Dockerfile

# Проверка успешности скачивания
if [ ! -f "bot/bot.py" ] || [ ! -f "docker-compose.yml" ] || [ ! -f "requirements.txt" ] || [ ! -f "Dockerfile" ]; then
    echo -e "${RED}Ошибка: Не удалось скачать файлы!${NC}"
    exit 1
fi

echo -e "${GREEN}Файлы успешно скачаны!${NC}\n"

# Создание .env файла, если его нет
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}Создание файла .env...${NC}"
    cat > .env << EOF
BOT_TOKEN=your_bot_token_here
SUPPORT_CHAT_ID=your_support_chat_id_here
ADMIN_IDS=your_admin_id_here
DB_PATH=/app/bot.db
EOF
    echo -e "${GREEN}Файл .env создан.${NC}"
    echo -e "${YELLOW}ВАЖНО: Отредактируйте .env файл и укажите ваши данные!${NC}\n"
    echo -e "${YELLOW}Команда для редактирования: nano $BOT_DIR/.env${NC}\n"
else
    echo -e "${GREEN}Файл .env уже существует.${NC}\n"
fi

# Создание пустого файла базы данных, если его нет
if [ ! -f "bot/bot.db" ]; then
    echo -e "${YELLOW}Создание файла базы данных...${NC}"
    touch bot/bot.db
    chmod 666 bot/bot.db
    echo -e "${GREEN}Файл базы данных создан!${NC}\n"
fi

echo -e "${GREEN}=== Установка завершена! ===${NC}\n"
echo -e "${YELLOW}Следующие шаги:${NC}"
echo "1. Отредактируйте файл .env: ${GREEN}nano $BOT_DIR/.env${NC}"
echo "2. Запустите бота: ${GREEN}cd $BOT_DIR && docker-compose up -d${NC}"
echo "3. Просмотр логов: ${GREEN}cd $BOT_DIR && docker-compose logs -f${NC}\n"
echo -e "${YELLOW}Для обновления используйте:${NC}"
echo "  ${GREEN}curl -sSL https://raw.githubusercontent.com/mdeadice/support-bot/main/bot/update.sh | bash${NC}\n"
