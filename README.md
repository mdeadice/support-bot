# Support Bot

Telegram бот для поддержки пользователей с системой тикетов, FAQ и админ-панелью.

## 🚀 Быстрая установка на VPS/VM

**📖 [Полная инструкция](INSTALL.md)** | **⚡ [Быстрый старт](QUICK_START.md)**

### Минимальная установка (3 команды):

```bash
# 1. Установка Docker
curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh

# 2. Установка бота
curl -sSL https://raw.githubusercontent.com/mdeadice/support-bot/main/install.sh | bash

# 3. Настройка и запуск
cd support-bot && nano .env && docker-compose up -d
```

**Не забудьте:**
- Получить токен у [@BotFather](https://t.me/BotFather)
- Создать Forum группу и добавить туда бота
- Узнать ID группы через [@userinfobot](https://t.me/userinfobot)

## Установка

### Автоматическая установка

```bash
curl -sSL https://raw.githubusercontent.com/mdeadice/support-bot/main/install.sh | bash
```

Или вручную:

```bash
curl -O https://raw.githubusercontent.com/mdeadice/support-bot/main/install.sh
chmod +x install.sh
./install.sh
```

### Ручная установка

1. Клонируйте репозиторий или скачайте файлы:
```bash
mkdir -p support-bot/bot && cd support-bot
curl -O https://raw.githubusercontent.com/mdeadice/support-bot/main/bot.py -o bot/bot.py
curl -O https://raw.githubusercontent.com/mdeadice/support-bot/main/docker-compose.yml
curl -O https://raw.githubusercontent.com/mdeadice/support-bot/main/requirements.txt
curl -O https://raw.githubusercontent.com/mdeadice/support-bot/main/Dockerfile
```

2. Создайте файл `.env`:
```bash
cat > .env << EOF
BOT_TOKEN=your_bot_token_here
SUPPORT_CHAT_ID=your_support_chat_id_here
ADMIN_IDS=your_admin_id_here
DB_PATH=/app/bot.db
EOF
```

3. Отредактируйте `.env` и укажите ваши данные

4. Запустите бота:
```bash
docker-compose up -d
```

## Обновление

### Автоматическое обновление

```bash
curl -sSL https://raw.githubusercontent.com/mdeadice/support-bot/main/update.sh | bash
```

Или вручную:

```bash
curl -O https://raw.githubusercontent.com/mdeadice/support-bot/main/update.sh
chmod +x update.sh
./update.sh
```

### Ручное обновление

1. Остановите бота:
```bash
docker-compose down
```

2. Скачайте обновленные файлы:
```bash
mkdir -p bot
curl -O https://raw.githubusercontent.com/mdeadice/support-bot/main/bot.py -o bot/bot.py
curl -O https://raw.githubusercontent.com/mdeadice/support-bot/main/docker-compose.yml
curl -O https://raw.githubusercontent.com/mdeadice/support-bot/main/requirements.txt
curl -O https://raw.githubusercontent.com/mdeadice/support-bot/main/Dockerfile
```

3. Пересоберите и запустите:
```bash
docker-compose build --no-cache
docker-compose up -d
```

## Использование

### Команды для пользователей

- `/start` - Главное меню

### Команды для операторов (в группе поддержки)

- `/ban [причина]` - Заблокировать пользователя
- `/unban [ID]` - Разблокировать пользователя
- `/close` - Закрыть тикет
- `/check` - Отправить вопрос "Могу помочь?"
- `/faq` - Отправить ответ из FAQ

### Команды для администраторов

- `/admin` - Админ-панель (в личных сообщениях)

## Переменные окружения

- `BOT_TOKEN` - Токен бота от @BotFather
- `SUPPORT_CHAT_ID` - ID группы поддержки (Forum группа)
- `ADMIN_IDS` - ID администраторов через запятую
- `DB_PATH` - Путь к базе данных (по умолчанию `/app/bot.db`)

## Управление

```bash
# Просмотр логов
docker-compose logs -f

# Остановка
docker-compose down

# Перезапуск
docker-compose restart

# Обновление
./update.sh
```

## Требования

- Docker
- docker-compose
- Python 3.11+ (в контейнере)

## Лицензия

MIT

