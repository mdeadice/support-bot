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
    
    # Останавливаем все контейнеры с именем support-bot (на случай если есть дубликаты)
    echo -e "${YELLOW}Проверка на дубликаты контейнеров...${NC}"
    docker stop support-bot 2>/dev/null || true
    docker rm support-bot 2>/dev/null || true
    # Останавливаем все контейнеры, содержащие support-bot в имени
    docker ps -a | grep support-bot | awk '{print $1}' | xargs -r docker stop 2>/dev/null || true
    docker ps -a | grep support-bot | awk '{print $1}' | xargs -r docker rm 2>/dev/null || true
    
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
    DB_SIZE=$(stat -f%z "bot/bot.db" 2>/dev/null || stat -c%s "bot/bot.db" 2>/dev/null || echo "0")
    if [ "$DB_SIZE" -gt 0 ]; then
        echo -e "${GREEN}Обнаружена база данных (размер: ${DB_SIZE} байт)${NC}"
        echo -e "${GREEN}Создание резервной копии базы данных...${NC}"
        BACKUP_FILE="bot/bot.db.backup.$(date +%Y%m%d_%H%M%S)"
        cp bot/bot.db "$BACKUP_FILE" 2>/dev/null || true
        if [ -f "$BACKUP_FILE" ]; then
            BACKUP_SIZE=$(stat -f%z "$BACKUP_FILE" 2>/dev/null || stat -c%s "$BACKUP_FILE" 2>/dev/null || echo "0")
            if [ "$BACKUP_SIZE" -gt 0 ]; then
                echo -e "${GREEN}Резервная копия создана: $BACKUP_FILE (размер: ${BACKUP_SIZE} байт)${NC}"
            else
                echo -e "${RED}ОШИБКА: Резервная копия создана, но пуста!${NC}"
                echo -e "${YELLOW}Обновление прервано для защиты данных.${NC}"
                rm -f "$BACKUP_FILE" 2>/dev/null || true
                exit 1
            fi
        else
            echo -e "${RED}ОШИБКА: Не удалось создать резервную копию!${NC}"
            echo -e "${YELLOW}Обновление прервано для защиты данных.${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}Файл БД существует, но пуст.${NC}"
    fi
else
    # Создаем файл БД, если его нет (только если БД действительно нет)
    echo -e "${YELLOW}База данных не найдена. Будет создана новая.${NC}"
    # НЕ создаем файл здесь - пусть бот создаст его при первом запуске
fi

# Убеждаемся, что директория bot существует и имеет правильные права
mkdir -p bot
chmod 755 bot 2>/dev/null || true

# Проверка и исправление DB_PATH в .env файле
if [ -f ".env" ]; then
    echo -e "${YELLOW}Проверка DB_PATH в .env...${NC}"
    if grep -q "DB_PATH=" .env; then
        # Проверяем, что путь правильный (должен быть /app/bot.db для контейнера)
        if ! grep -q "DB_PATH=/app/bot.db" .env; then
            echo -e "${YELLOW}Исправление DB_PATH в .env...${NC}"
            # Заменяем любую строку DB_PATH на правильную
            sed -i.bak 's|^DB_PATH=.*|DB_PATH=/app/bot.db|' .env 2>/dev/null || \
            sed -i 's|^DB_PATH=.*|DB_PATH=/app/bot.db|' .env 2>/dev/null || true
            echo -e "${GREEN}DB_PATH исправлен на /app/bot.db${NC}"
        fi
    else
        echo -e "${YELLOW}Добавление DB_PATH в .env...${NC}"
        echo "DB_PATH=/app/bot.db" >> .env
        echo -e "${GREEN}DB_PATH добавлен в .env${NC}"
    fi
fi

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

# Показываем информацию о резервных копиях
BACKUP_COUNT=$(ls -1 bot/bot.db.backup.* 2>/dev/null | wc -l)
if [ "$BACKUP_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}Доступные резервные копии БД:${NC}"
    ls -lh bot/bot.db.backup.* 2>/dev/null | tail -5
    
    # Проверяем, есть ли непустые резервные копии
    NON_EMPTY_BACKUPS=$(find bot -name "bot.db.backup.*" -size +0 2>/dev/null | wc -l)
    if [ "$NON_EMPTY_BACKUPS" -eq 0 ]; then
        echo -e "${RED}ВНИМАНИЕ: Все резервные копии пустые (0 байт)!${NC}"
        echo -e "${YELLOW}Это означает, что БД была пустой или резервное копирование не сработало.${NC}"
    fi
    
    echo -e "${YELLOW}Для восстановления БД из резервной копии:${NC}"
    echo -e "  ${GREEN}cp bot/bot.db.backup.YYYYMMDD_HHMMSS bot/bot.db${NC}"
    echo -e "  ${GREEN}chmod 666 bot/bot.db${NC}"
    echo ""
fi

# Проверка текущей БД
if [ -f "bot/bot.db" ]; then
    CURRENT_DB_SIZE=$(stat -f%z "bot/bot.db" 2>/dev/null || stat -c%s "bot/bot.db" 2>/dev/null || echo "0")
    if [ "$CURRENT_DB_SIZE" -eq 0 ]; then
        echo -e "${RED}ВНИМАНИЕ: Текущая БД пуста (0 байт)!${NC}"
        echo -e "${YELLOW}Если у вас была БД с данными, проверьте резервные копии выше.${NC}"
    else
        echo -e "${GREEN}Текущая БД существует (размер: ${CURRENT_DB_SIZE} байт)${NC}"
    fi
else
    echo -e "${YELLOW}Текущая БД не найдена. Будет создана новая при первом запуске.${NC}"
fi

echo -e "Просмотр логов: ${GREEN}cd $BOT_DIR && docker-compose logs -f${NC}\n"
