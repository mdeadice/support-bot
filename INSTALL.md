# Инструкция по установке Support Bot на VPS/VM

## Требования

- VPS/VM с Ubuntu/Debian (или другой Linux дистрибутив)
- Доступ по SSH
- Минимум 512MB RAM
- 1GB свободного места

## Пошаговая установка

### Шаг 1: Подключение к серверу

Подключитесь к вашему VPS через SSH:
```bash
ssh user@your-server-ip
```

### Шаг 2: Проверка Docker (если уже установлен)

Если Docker уже установлен, просто проверьте:

```bash
docker --version
docker-compose --version
```

Если команды работают, переходите к шагу 3.

### Шаг 2 (альтернативный): Установка Docker (если не установлен)

#### Для Ubuntu/Debian:

```bash
# Обновление системы
sudo apt update && sudo apt upgrade -y

# Установка необходимых пакетов
sudo apt install -y curl git

# Установка Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Добавление пользователя в группу docker (чтобы не использовать sudo)
sudo usermod -aG docker $USER

# Установка docker-compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Перезагрузка сессии (или выйдите и войдите снова)
newgrp docker
```

#### Проверка установки:

```bash
docker --version
docker-compose --version
```

### Шаг 3: Установка бота

#### Вариант 1: Автоматическая установка (рекомендуется)

```bash
curl -sSL https://raw.githubusercontent.com/mdeadice/support-bot/main/install.sh | bash
```

#### Вариант 2: Ручная установка

```bash
# Создание директории
mkdir -p support-bot && cd support-bot

# Скачивание файлов
curl -O https://raw.githubusercontent.com/mdeadice/support-bot/main/bot.py
curl -O https://raw.githubusercontent.com/mdeadice/support-bot/main/docker-compose.yml
curl -O https://raw.githubusercontent.com/mdeadice/support-bot/main/requirements.txt
curl -O https://raw.githubusercontent.com/mdeadice/support-bot/main/Dockerfile

# Создание .env файла
cat > .env << EOF
BOT_TOKEN=your_bot_token_here
SUPPORT_CHAT_ID=your_support_chat_id_here
ADMIN_IDS=your_admin_id_here
DB_PATH=/app/bot.db
EOF
```

### Шаг 4: Настройка бота

Отредактируйте файл `.env`:

```bash
nano .env
```

Или используйте `vi`:
```bash
vi .env
```

**Необходимые параметры:**

1. **BOT_TOKEN** - Получите у [@BotFather](https://t.me/BotFather) в Telegram:
   - Напишите `/newbot`
   - Следуйте инструкциям
   - Скопируйте токен

2. **SUPPORT_CHAT_ID** - ID вашей группы поддержки (Forum группа):
   - **Самый простой способ:** Добавьте вашего бота в группу и отправьте команду `/get_chat_id`
   - Бот покажет Chat ID (будет отрицательное число, например: `-1001234567890`)
   - **Альтернатива:** Используйте [@getidsbot](https://t.me/getidsbot) или [@RawDataBot](https://t.me/RawDataBot)
   - Подробнее: см. [HOW_TO_GET_CHAT_ID.md](HOW_TO_GET_CHAT_ID.md)

3. **ADMIN_IDS** - ID администраторов через запятую:
   - Узнайте свой ID через [@userinfobot](https://t.me/userinfobot)
   - Если несколько админов: `123456789,987654321`

4. **DB_PATH** - Оставьте как есть: `/app/bot.db`

**Пример .env файла:**
```env
BOT_TOKEN=1234567890:ABCdefGHIjklMNOpqrsTUVwxyz
SUPPORT_CHAT_ID=-1001234567890
ADMIN_IDS=123456789,987654321
DB_PATH=/app/bot.db
```

### Шаг 5: Настройка группы поддержки

1. Создайте группу в Telegram
2. Преобразуйте её в **Forum группу** (в настройках группы)
3. Добавьте бота в группу как администратора
4. Дайте боту права:
   - Удаление сообщений
   - Управление темами
   - Закрепление сообщений

### Шаг 6: Запуск бота

```bash
cd support-bot
docker-compose up -d
```

### Шаг 7: Проверка работы

Просмотр логов:
```bash
docker-compose logs -f
```

Если всё работает, вы увидите:
```
Бот запущен. Банов: 0
```

Нажмите `Ctrl+C` для выхода из логов.

## Управление ботом

### Просмотр логов
```bash
cd support-bot
docker-compose logs -f
```

### Остановка бота
```bash
cd support-bot
docker-compose down
```

### Перезапуск бота
```bash
cd support-bot
docker-compose restart
```

### Обновление бота
```bash
cd support-bot
curl -sSL https://raw.githubusercontent.com/mdeadice/support-bot/main/update.sh | bash
```

Или вручную:
```bash
cd support-bot
curl -O https://raw.githubusercontent.com/mdeadice/support-bot/main/update.sh
chmod +x update.sh
./update.sh
```

## Решение проблем

### Бот не запускается

1. Проверьте логи:
```bash
docker-compose logs
```

2. Проверьте .env файл:
```bash
cat .env
```

3. Проверьте, что все переменные заполнены

### Ошибка "Permission denied"

```bash
sudo chmod +x install.sh
sudo chmod +x update.sh
```

Или используйте sudo для docker-compose:
```bash
sudo docker-compose up -d
```

### Бот не отвечает

1. Проверьте, что бот запущен:
```bash
docker-compose ps
```

2. Проверьте логи на ошибки:
```bash
docker-compose logs | grep -i error
```

3. Убедитесь, что токен правильный

### Проблемы с правами Docker

```bash
sudo usermod -aG docker $USER
newgrp docker
```

### Docker уже установлен

Если Docker уже установлен (как в вашем случае), просто проверьте версию и продолжайте:

```bash
docker --version
docker-compose --version
```

Если команды работают, переходите к установке бота.

## Автозапуск при перезагрузке сервера

Docker Compose уже настроен на автозапуск (`restart: unless-stopped`), но если нужно убедиться:

```bash
# Проверка статуса
docker-compose ps

# Если контейнер остановлен, запустите
docker-compose up -d
```

## Безопасность

1. **Не делитесь .env файлом** - он содержит секретные данные
2. **Используйте firewall** для защиты сервера
3. **Регулярно обновляйте** систему и Docker

## Дополнительная информация

- Полная документация: см. [README.md](README.md)
- Проблемы? Создайте Issue на GitHub
