# Исправление ошибки монтирования базы данных

## Проблема
Docker не может смонтировать несуществующий файл `bot.db`.

## Решение

### Вариант 1: Монтирование всей директории (рекомендуется)

Измените `docker-compose.yml`:

```yaml
version: '3.9'

services:
  support-bot:
    build: .
    container_name: support-bot
    restart: unless-stopped
    env_file:
      - .env
    environment:
      PYTHONUNBUFFERED: 1
    volumes:
      - ./bot:/app
```

В `.env` укажите:
```env
DB_PATH=bot.db
```

Или:
```env
DB_PATH=/app/bot.db
```

### Вариант 2: Создать файл перед запуском

```bash
# Создайте пустой файл базы данных
touch bot/bot.db

# Затем запустите
docker-compose up -d
```

## Для вашего случая (путь /opt/support-bot/bot/bot.db)

Если ваш docker-compose.yml находится в `/opt/support-bot/`, то:

1. Убедитесь, что структура такая:
```
/opt/support-bot/
├── bot/
│   ├── bot.db
│   └── bot.py
├── docker-compose.yml
├── Dockerfile
├── requirements.txt
└── .env
```

2. В `docker-compose.yml` используйте:
```yaml
volumes:
  - ./bot:/app
```

3. В `.env` укажите:
```env
DB_PATH=bot.db
```

4. Запустите:
```bash
cd /opt/support-bot
docker-compose up -d
```

