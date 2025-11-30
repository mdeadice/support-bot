#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Обновление Support Bot ===${NC}\n"

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

# Проверка, что мы в правильной директории
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}Ошибка: docker-compose.yml не найден!${NC}"
    echo "Убедитесь, что вы находитесь в директории с ботом."
    exit 1
fi

echo -e "${YELLOW}Остановка бота...${NC}"
docker-compose down 2>/dev/null || docker compose down 2>/dev/null

# Защита базы данных - создаем резервную копию перед обновлением
if [ -f "bot/bot.db" ]; then
    echo -e "${GREEN}Создание резервной копии базы данных...${NC}"
    cp bot/bot.db "bot/bot.db.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
    echo -e "${GREEN}Резервная копия создана!${NC}"
fi

echo -e "${GREEN}Скачивание обновленных файлов...${NC}"

# Создание структуры папок если её нет
mkdir -p bot

# Скачивание обновленных файлов
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

echo -e "${GREEN}Файлы успешно обновлены!${NC}\n"

# Пересборка и запуск
echo -e "${YELLOW}Пересборка контейнера...${NC}"
docker-compose build --no-cache 2>/dev/null || docker compose build --no-cache 2>/dev/null

echo -e "${YELLOW}Запуск бота...${NC}"
docker-compose up -d 2>/dev/null || docker compose up -d 2>/dev/null

echo -e "${GREEN}=== Обновление завершено! ===${NC}\n"
echo -e "Просмотр логов: ${GREEN}docker-compose logs -f${NC}\n"

