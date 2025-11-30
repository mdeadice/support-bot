# 🖥️ Быстрая установка на VPS

## Минимальные требования

- Ubuntu 20.04+ / Debian 11+ / CentOS 8+
- 512 MB RAM (минимум)
- 1 GB свободного места
- Python 3.8+

## Пошаговая установка

### 1. Подключение к VPS

```bash
ssh root@your-vps-ip
# или
ssh user@your-vps-ip
```

### 2. Обновление системы

```bash
# Ubuntu/Debian
sudo apt update && sudo apt upgrade -y

# CentOS/RHEL
sudo yum update -y
```

### 3. Установка необходимых пакетов

```bash
# Ubuntu/Debian
sudo apt install -y python3 python3-pip python3-venv git

# CentOS/RHEL
sudo yum install -y python3 python3-pip git
```

### 4. Клонирование репозитория

```bash
cd /opt  # или любая другая директория
git clone https://github.com/mdeadice/support-bot.git
cd support-bot
```

### 5. Запуск установщика

```bash
bash install.sh
```

Установщик автоматически:
- Проверит Python
- Установит зависимости
- Создаст `.env` файл
- Предложит настроить systemd (ответьте `y`)

### 6. Настройка конфигурации

```bash
nano .env
```

Заполните:
- `BOT_TOKEN` - получите у @BotFather
- `SUPPORT_CHAT_ID` - ID группы (должна быть форумом)
- `ADMIN_IDS` - ваш Telegram ID (можно несколько через запятую)

### 7. Настройка systemd (если не сделано автоматически)

```bash
# Отредактируйте пути в service файле
sudo nano /etc/systemd/system/support-bot.service

# Измените:
# WorkingDirectory=/opt/support-bot  (ваш путь)
# ExecStart=/usr/bin/python3 /opt/support-bot/bot.py  (ваш путь)

# Включите и запустите
sudo systemctl daemon-reload
sudo systemctl enable support-bot
sudo systemctl start support-bot
```

### 8. Проверка работы

```bash
# Статус
sudo systemctl status support-bot

# Логи
sudo journalctl -u support-bot -f
```

## Управление ботом

```bash
# Запуск
sudo systemctl start support-bot

# Остановка
sudo systemctl stop support-bot

# Перезапуск
sudo systemctl restart support-bot

# Статус
sudo systemctl status support-bot

# Просмотр логов
sudo journalctl -u support-bot -f

# Последние 100 строк логов
sudo journalctl -u support-bot -n 100
```

## Альтернатива: Docker

Если предпочитаете Docker:

```bash
# Установите Docker
sudo apt install -y docker.io docker-compose
sudo systemctl enable docker
sudo systemctl start docker

# Клонируйте репозиторий
git clone https://github.com/mdeadice/support-bot.git
cd support-bot

# Настройте .env
nano .env

# Запустите
docker-compose up -d

# Логи
docker-compose logs -f
```

## Решение проблем

### Бот не запускается

```bash
# Проверьте логи
sudo journalctl -u support-bot -n 50

# Проверьте .env файл
cat .env

# Проверьте Python
python3 --version

# Проверьте зависимости
pip3 list | grep aiogram
```

### Ошибка "Permission denied"

```bash
# Проверьте права на файлы
ls -la bot.py
chmod +x bot.py

# Проверьте права на директорию
ls -la
```

### Бот падает с ошибкой

```bash
# Запустите вручную для отладки
cd /opt/support-bot
python3 bot.py
```

## Обновление

```bash
# Остановите бота
sudo systemctl stop support-bot

# Обновите код
cd /opt/support-bot
git pull

# Обновите зависимости
pip3 install -r requirements.txt --upgrade

# Запустите снова
sudo systemctl start support-bot
```

## Безопасность

1. **Не используйте root пользователя** (рекомендуется):
   ```bash
   # Создайте отдельного пользователя
   sudo useradd -m -s /bin/bash support-bot
   sudo chown -R support-bot:support-bot /opt/support-bot
   
   # В service файле измените:
   # User=support-bot
   # Group=support-bot
   ```

2. **Настройте firewall** (если нужно):
   ```bash
   sudo ufw allow 22/tcp  # SSH
   sudo ufw enable
   ```

3. **Регулярно обновляйте систему**:
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

## Полезные команды

```bash
# Размер базы данных
du -h bot/bot.db

# Использование памяти
free -h

# Использование диска
df -h

# Процессы Python
ps aux | grep python
```

---

**Готово! Бот должен работать 24/7 на вашем VPS** 🚀

