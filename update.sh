#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

BOT_DIR="/opt/support-bot"

echo -e "${GREEN}=== Обновление Support Bot ===${NC}\n"

# Проверка прав root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${YELLOW}Предупреждение: Рекомендуется запускать от root (sudo)${NC}"
fi

# Проверка наличия Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Ошибка: Docker не установлен!${NC}"
    exit 1
fi

# Проверка наличия docker-compose
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}Ошибка: docker-compose не установлен!${NC}"
    exit 1
fi

# Проверка существования директории
if [ ! -d "$BOT_DIR" ]; then
    echo -e "${RED}Ошибка: Бот не установлен в $BOT_DIR${NC}"
    echo -e "${YELLOW}Сначала выполните установку:${NC}"
    echo "curl -sSL https://raw.githubusercontent.com/mdeadice/support-bot/main/bot/install.sh | bash"
    exit 1
fi

# Переход в директорию
cd "$BOT_DIR" || exit 1

# Остановка и удаление старого контейнера и образа
if [ -f "docker-compose.yml" ]; then
    echo -e "${YELLOW}Остановка и удаление старого контейнера...${NC}"
    docker-compose down --remove-orphans 2>/dev/null || docker compose down --remove-orphans 2>/dev/null
    
    # Удаляем старый образ, чтобы гарантировать пересборку
    echo -e "${YELLOW}Удаление старого образа...${NC}"
    # Пытаемся удалить образ по разным возможным именам
    docker rmi support-bot-support-bot:latest 2>/dev/null || true
    docker rmi support-bot_support-bot:latest 2>/dev/null || true
    docker rmi $(docker images | grep support-bot | awk '{print $3}') 2>/dev/null || true
    
    # Очистка неиспользуемых образов
    docker image prune -f 2>/dev/null || true
fi

# Защита базы данных - создаем резервную копию перед обновлением
if [ -f "bot/bot.db" ]; then
    echo -e "${GREEN}Создание резервной копии базы данных...${NC}"
    cp bot/bot.db "bot/bot.db.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
    echo -e "${GREEN}Резервная копия создана!${NC}"
else
    # Создаем файл БД, если его нет
    echo -e "${YELLOW}Создание файла базы данных...${NC}"
    touch bot/bot.db 2>/dev/null || true
    chmod 666 bot/bot.db 2>/dev/null || true
fi

# Убеждаемся, что директория bot существует и имеет правильные права
mkdir -p bot
chmod 755 bot 2>/dev/null || true

echo -e "${GREEN}Скачивание обновленных файлов...${NC}"

# Создание структуры папок если её нет
mkdir -p bot

# Скачивание обновленных файлов
echo -e "Скачивание bot.py..."
curl -sL -o bot/bot.py https://raw.githubusercontent.com/mdeadice/support-bot/main/bot.py || curl -sL -o bot/bot.py https://raw.githubusercontent.com/mdeadice/support-bot/main/bot/bot.py

echo -e "Скачивание docker-compose.yml..."
curl -s -o docker-compose.yml https://raw.githubusercontent.com/mdeadice/support-bot/main/docker-compose.yml || curl -s -o docker-compose.yml https://raw.githubusercontent.com/mdeadice/support-bot/main/bot/docker-compose.yml

echo -e "Скачивание requirements.txt..."
curl -s -o requirements.txt https://raw.githubusercontent.com/mdeadice/support-bot/main/requirements.txt || curl -s -o requirements.txt https://raw.githubusercontent.com/mdeadice/support-bot/main/bot/requirements.txt

echo -e "Скачивание Dockerfile..."
curl -s -o Dockerfile https://raw.githubusercontent.com/mdeadice/support-bot/main/Dockerfile || curl -s -o Dockerfile https://raw.githubusercontent.com/mdeadice/support-bot/main/bot/Dockerfile

# Проверка успешности скачивания
if [ ! -f "bot/bot.py" ] || [ ! -f "docker-compose.yml" ] || [ ! -f "requirements.txt" ] || [ ! -f "Dockerfile" ]; then
    echo -e "${RED}Ошибка: Не удалось скачать файлы!${NC}"
    exit 1
fi

# Проверка, что requirements.txt содержит aiosqlite
if ! grep -q "aiosqlite" requirements.txt; then
    echo -e "${RED}Ошибка: requirements.txt не содержит aiosqlite!${NC}"
    echo -e "${YELLOW}Добавляю aiosqlite в requirements.txt...${NC}"
    echo "aiosqlite==0.19.0" >> requirements.txt
fi

echo -e "${GREEN}Файлы успешно обновлены!${NC}\n"
echo -e "${YELLOW}Содержимое requirements.txt:${NC}"
cat requirements.txt
echo ""

# Пересборка и запуск
echo -e "${YELLOW}Пересборка контейнера (это может занять время)...${NC}"
if command -v docker-compose &> /dev/null; then
    # Полная пересборка без кеша
    docker-compose build --no-cache --pull
    if [ $? -ne 0 ]; then
        echo -e "${RED}Ошибка при сборке образа!${NC}"
        exit 1
    fi
    echo -e "${YELLOW}Запуск бота...${NC}"
    docker-compose up -d --force-recreate
else
    # Полная пересборка без кеша
    docker compose build --no-cache --pull
    if [ $? -ne 0 ]; then
        echo -e "${RED}Ошибка при сборке образа!${NC}"
        exit 1
    fi
    echo -e "${YELLOW}Запуск бота...${NC}"
    docker compose up -d --force-recreate
fi

# Проверка статуса
sleep 3
echo -e "\n${YELLOW}Проверка статуса контейнера...${NC}"
if command -v docker-compose &> /dev/null; then
    docker-compose ps
    echo -e "\n${GREEN}Проверка логов (последние 20 строк):${NC}"
    docker-compose logs --tail=20
else
    docker compose ps
    echo -e "\n${GREEN}Проверка логов (последние 20 строк):${NC}"
    docker compose logs --tail=20
fi

echo -e "${GREEN}=== Обновление завершено! ===${NC}\n"
echo -e "Просмотр логов: ${GREEN}cd $BOT_DIR && docker-compose logs -f${NC}\n"
