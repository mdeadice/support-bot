#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Установка Support Bot ===${NC}\n"

# Проверка наличия Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Ошибка: Docker не установлен!${NC}"
    echo "Установите Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

# Проверка наличия docker-compose
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}Ошибка: docker-compose не установлен!${NC}"
    echo "Установите docker-compose или используйте Docker с встроенным compose"
    exit 1
fi

# Создание директории для бота
BOT_DIR="support-bot"
if [ -d "$BOT_DIR" ]; then
    echo -e "${YELLOW}Директория $BOT_DIR уже существует.${NC}"
    
    # Проверка наличия базы данных
    DB_BACKUP=""
    if [ -f "$BOT_DIR/bot/bot.db" ]; then
        echo -e "${YELLOW}⚠️  Обнаружена база данных!${NC}"
        DB_BACKUP="${BOT_DIR}/bot/bot.db.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${GREEN}Создание резервной копии БД: $DB_BACKUP${NC}"
        cp "$BOT_DIR/bot/bot.db" "$DB_BACKUP"
        echo -e "${GREEN}Резервная копия создана!${NC}"
    fi
    
    read -p "Перезаписать файлы? (БД будет сохранена) (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Отмена установки."
        exit 1
    fi
    
    # Сохраняем важные файлы
    BACKUP_DIR="${BOT_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Копируем базу данных и .env если есть
    if [ -f "$BOT_DIR/bot/bot.db" ]; then
        cp "$BOT_DIR/bot/bot.db" "$BACKUP_DIR/bot.db" 2>/dev/null || true
    fi
    if [ -f "$BOT_DIR/.env" ]; then
        cp "$BOT_DIR/.env" "$BACKUP_DIR/.env" 2>/dev/null || true
    fi
    
    # Удаляем директорию
    rm -rf "$BOT_DIR"
    
    # Восстанавливаем важные файлы
    mkdir -p "$BOT_DIR/bot"
    if [ -f "$BACKUP_DIR/bot.db" ]; then
        cp "$BACKUP_DIR/bot.db" "$BOT_DIR/bot/bot.db"
        echo -e "${GREEN}База данных восстановлена!${NC}"
    fi
    if [ -f "$BACKUP_DIR/.env" ]; then
        cp "$BACKUP_DIR/.env" "$BOT_DIR/.env"
        echo -e "${GREEN}Файл .env восстановлен!${NC}"
    fi
    
    # Удаляем временную резервную копию
    rm -rf "$BACKUP_DIR"
fi

mkdir -p "$BOT_DIR"
cd "$BOT_DIR" || exit 1

echo -e "${GREEN}Скачивание файлов с GitHub...${NC}"

# Создание структуры папок
mkdir -p bot

# Скачивание файлов
echo -e "Скачивание bot.py..."
curl -s -o bot/bot.py https://raw.githubusercontent.com/mdeadice/support-bot/main/bot.py
echo -e "Скачивание docker-compose.yml..."
curl -s -o docker-compose.yml https://raw.githubusercontent.com/mdeadice/support-bot/main/docker-compose.yml
echo -e "Скачивание requirements.txt..."
curl -s -o requirements.txt https://raw.githubusercontent.com/mdeadice/support-bot/main/requirements.txt
echo -e "Скачивание Dockerfile..."
curl -s -o Dockerfile https://raw.githubusercontent.com/mdeadice/support-bot/main/Dockerfile

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
else
    echo -e "${GREEN}Файл .env уже существует.${NC}\n"
fi

# Проверка docker-compose.yml на наличие env_file
if ! grep -q "env_file:" docker-compose.yml; then
    echo -e "${YELLOW}Обновление docker-compose.yml для использования .env...${NC}"
    # Создаем резервную копию
    cp docker-compose.yml docker-compose.yml.bak
    # Добавляем env_file (для Linux)
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sed -i '/environment:/a\    env_file:\n      - .env' docker-compose.yml
    # Для macOS
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' '/environment:/a\
    env_file:\
      - .env' docker-compose.yml
    fi
fi

echo -e "${GREEN}=== Установка завершена! ===${NC}\n"
echo -e "${YELLOW}Следующие шаги:${NC}"
echo "1. Отредактируйте файл .env и укажите ваши данные"
echo "2. Запустите бота командой: ${GREEN}docker-compose up -d${NC}"
echo "3. Просмотр логов: ${GREEN}docker-compose logs -f${NC}"
echo "4. Остановка бота: ${GREEN}docker-compose down${NC}\n"

