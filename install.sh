#!/bin/bash

# --- ЦВЕТА ДЛЯ КРАСОТЫ ---
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

clear
echo -e "${CYAN}=====================================================${NC}"
echo -e "${CYAN}   🚀 УСТАНОВКА TELEGRAM SUPPORT BOT by VME BOOST    ${NC}"
echo -e "${CYAN}=====================================================${NC}"
echo ""

# 1. ПРОВЕРКА ROOT
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}❌ Ошибка: Запустите скрипт от имени root (sudo).${NC}"
  exit
fi

# 2. ПОДГОТОВКА СИСТЕМЫ
echo -e "${YELLOW}📦 Обновляем систему и ставим Python... (это займет минуту)${NC}"
apt-get update -qq > /dev/null
apt-get install -y python3-pip python3-venv git -qq > /dev/null

# 3. СОЗДАНИЕ ПАПКИ
INSTALL_DIR="/opt/support-bot"
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# 4. СКАЧИВАНИЕ ФАЙЛОВ
echo -e "${YELLOW}⬇️  Скачиваем файлы бота...${NC}"
# Удаляем старое, если есть
rm -f bot.py requirements.txt

# ССЫЛКИ НА ТВОЙ РЕПОЗИТОРИЙ
wget -q https://raw.githubusercontent.com/mdeadice/support-bot/main/bot.py
wget -q https://raw.githubusercontent.com/mdeadice/support-bot/main/requirements.txt

# Проверка, скачалось ли
if [ ! -f "bot.py" ]; then
    echo -e "${RED}❌ Ошибка: Не удалось скачать bot.py. Проверьте интернет или GitHub!${NC}"
    exit
fi

# 5. ВИРТУАЛЬНОЕ ОКРУЖЕНИЕ
echo -e "${YELLOW}🐍 Настраиваем виртуальное окружение...${NC}"
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt -q

clear
echo -e "${GREEN}✅ Система готова! Теперь настроим самого бота.${NC}"
echo -e "${CYAN}-----------------------------------------------------${NC}"

# 6. НАСТРОЙКА (ИНТЕРАКТИВ)

# --- ШАГ 1: ТОКЕН ---
echo -e "\n${YELLOW}1️⃣  ШАГ ПЕРВЫЙ: Токен бота${NC}"
echo "   1. Зайдите в Telegram и найдите бота @BotFather"
echo "   2. Напишите ему команду /newbot"
echo "   3. Придумайте имя и юзернейм"
echo "   4. Скопируйте длинный HTTP API Token"
echo -n "👉 Вставьте токен сюда и нажмите Enter: "
read TOKEN

# --- ШАГ 2: АДМИНЫ ---
echo -e "\n${YELLOW}2️⃣  ШАГ ВТОРОЙ: ID Админов${NC}"
echo "   1. Найдите бота @userinfobot"
echo "   2. Нажмите Start и скопируйте ID"
echo "   ℹ️ Если админов несколько, введите их через запятую (напр: 12345, 67890)"
echo -n "👉 Введите ID (только цифры и запятые): "
read ADMIN_ID

# --- ШАГ 3: ГРУППА ---
echo -e "\n${YELLOW}3️⃣  ШАГ ТРЕТИЙ: ID группы поддержки${NC}"
echo "   1. Создайте новую группу в Telegram"
echo "   2. Добавьте туда вашего бота и сделайте АДМИНИСТРАТОРОМ"
echo "   3. Добавьте в группу бота @GetMyChatID_Bot"
echo "   4. Скопируйте 'Chat ID' из сообщения (обычно начинается на -100...)"
echo -n "👉 Введите ID группы (вместе с минусом): "
read CHAT_ID

# Запись в .env
cat <<EOF > .env
BOT_TOKEN=$TOKEN
SUPPORT_CHAT_ID=$CHAT_ID
ADMIN_IDS=$ADMIN_ID
DB_PATH=$INSTALL_DIR/bot.db
EOF

# 7. НАСТРОЙКА SERVICE
echo -e "\n${YELLOW}⚙️  Запускаем вечную службу...${NC}"

# Останавливаем, если был
systemctl stop support-bot 2>/dev/null

SERVICE_FILE="/etc/systemd/system/support-bot.service"
cat <<EOF > $SERVICE_FILE
[Unit]
Description=Telegram Support Bot
After=network.target

[Service]
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/venv/bin/python bot.py
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable support-bot
systemctl start support-bot

# 8. ФИНАЛ
clear
echo -e "${GREEN}=====================================================${NC}"
echo -e "${GREEN}🎉  ПОЗДРАВЛЯЮ! БОТ УСПЕШНО ЗАПУЩЕН!  🎉${NC}"
echo -e "${GREEN}=====================================================${NC}"
echo ""
echo -e "Статус: $(systemctl is-active support-bot)"
echo ""
echo -e "${CYAN}Полезные команды:${NC}"
echo -e "  🔄 Перезагрузить:  ${YELLOW}systemctl restart support-bot${NC}"
echo -e "  🛑 Остановить:     ${YELLOW}systemctl stop support-bot${NC}"
echo -e "  📜 Читать логи:    ${YELLOW}journalctl -u support-bot -f${NC}"
echo ""
echo "Теперь зайдите в бота и нажмите /start"