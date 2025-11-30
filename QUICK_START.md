# 🚀 Быстрый старт - Установка бота на VPS

## Скопируйте и выполните команды по порядку:

### 1. Установка Docker (если не установлен)

```bash
curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh
sudo usermod -aG docker $USER
newgrp docker
```

### 2. Установка docker-compose

```bash
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### 3. Установка бота

```bash
curl -sSL https://raw.githubusercontent.com/mdeadice/support-bot/main/install.sh | bash
```

### 4. Настройка конфигурации

```bash
cd support-bot
nano .env
```

**В файле .env укажите:**
- `BOT_TOKEN` - получите у @BotFather
- `SUPPORT_CHAT_ID` - ID вашей Forum группы (узнайте через @userinfobot)
- `ADMIN_IDS` - ваш Telegram ID (через запятую, если несколько)

**Пример:**
```env
BOT_TOKEN=1234567890:ABCdefGHIjklMNOpqrsTUVwxyz
SUPPORT_CHAT_ID=-1001234567890
ADMIN_IDS=123456789
DB_PATH=/app/bot.db
```

### 5. Запуск бота

```bash
docker-compose up -d
```

### 6. Проверка работы

```bash
docker-compose logs -f
```

Нажмите `Ctrl+C` для выхода.

---

## 📋 Полезные команды

```bash
# Просмотр логов
docker-compose logs -f

# Остановка
docker-compose down

# Перезапуск
docker-compose restart

# Обновление
curl -sSL https://raw.githubusercontent.com/mdeadice/support-bot/main/update.sh | bash
```

---

## ❓ Полная инструкция

См. [INSTALL.md](INSTALL.md) для подробной инструкции и решения проблем.

