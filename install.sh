#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' 


if ! lsb_release -a 2>/dev/null | grep -qi "ubuntu"; then
    echo -e "${RED}خطا: این اسکریپت فقط برای اوبونتو طراحی شده است.${NC}"
    exit 1
fi

PYTHON_MIN_VERSION="3.8"
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
if ! dpkg --compare-versions "$PYTHON_VERSION" ge "$PYTHON_MIN_VERSION"; then
    echo -e "${RED}خطا: پایتون $PYTHON_MIN_VERSION یا بالاتر لازم است. یافت‌شده: $PYTHON_VERSION${NC}"
    echo -e "${YELLOW}در حال نصب پایتون 3.8...${NC}"
    sudo apt update
    sudo apt install -y python3.8 python3.8-venv python3-pip
fi

echo -e "${YELLOW}در حال نصب وابستگی‌های سیستمی...${NC}"
sudo apt update
sudo apt install -y python3 python3-pip python3-venv git

echo -e "${YELLOW}در حال تنظیم محیط مجازی پایتون...${NC}"
python3 -m venv venv
source venv/bin/activate

echo -e "${YELLOW}در حال نصب وابستگی‌های پایتون...${NC}"
pip install --upgrade pip
pip install -r requirements.txt

if [ $? -eq 0 ]; then
    echo -e "${GREEN}وابستگی‌ها با موفقیت نصب شدند!${NC}"
else
    echo -e "${RED}خطا: نصب وابستگی‌ها ناموفق بود. شبکه یا فایل requirements.txt را بررسی کنید.${NC}"
    exit 1
fi

deactivate
echo -e "${YELLOW}لطفاً توکن ربات تلگرام را وارد کنید (از @BotFather دریافت کنید):${NC}"
read -r BOT_TOKEN
if [ -z "$BOT_TOKEN" ]; then
    echo -e "${RED}خطا: توکن نمی‌تواند خالی باشد!${NC}"
    exit 1
fi

echo -e "${YELLOW}لطفاً آیدی‌های عددی ادمین‌ها را وارد کنید (با کاما جدا کنید، مثلاً: 123456789,987654321):${NC}"
echo -e "${YELLOW}برای دریافت آیدی عددی، می‌توانید از ربات @userinfobot در تلگرام استفاده کنید.${NC}"
read -r ADMIN_IDS_INPUT

ADMIN_IDS=()
IFS=',' read -ra ID_ARRAY <<< "$ADMIN_IDS_INPUT"
for ID in "${ID_ARRAY[@]}"; do
    ID=$(echo "$ID" | tr -d ' ')
    if [[ "$ID" =~ ^[0-9]+$ ]]; then
        ADMIN_IDS+=("$ID")
    else
        echo -e "${RED}خطا: '$ID' یک آیدی عددی معتبر نیست!${NC}"
        exit 1
    fi
done

if [ ${#ADMIN_IDS[@]} -eq 0 ]; then
    echo -e "${RED}خطا: حداقل یک آیدی ادمین باید وارد شود!${NC}"
    exit 1
fi

ADMIN_IDS_PYTHON=$(printf "%s," "${ADMIN_IDS[@]}")
ADMIN_IDS_PYTHON="[${ADMIN_IDS_PYTHON%,}]"

echo -e "${YELLOW}در حال ایجاد فایل config.py...${NC}"
cat > config.py << EOL


TOKEN = "$BOT_TOKEN"
ADMIN_IDS = $ADMIN_IDS_PYTHON
EOL

if [ $? -eq 0 ]; then
    echo -e "${GREEN}فایل config.py با موفقیت ایجاد شد!${NC}"
else
    echo -e "${RED}خطا: نتوانستیم فایل config.py را ایجاد کنیم!${NC}"
    exit 1
fi

echo -e "${YELLOW}لطفاً نام کاربری سیستم را وارد کنید (کاربری که ربات با آن اجرا می‌شود):${NC}"
read -r SYSTEM_USER
if [ -z "$SYSTEM_USER" ]; then
    echo -e "${RED}خطا: نام کاربری نمی‌تواند خالی باشد!${NC}"
    exit 1
fi

if ! id "$SYSTEM_USER" >/dev/null 2>&1; then
    echo -e "${RED}خطا: کاربر '$SYSTEM_USER' وجود ندارد!${NC}"
    exit 1
fi

echo -e "${YELLOW}در حال تنظیم سرویس systemd برای اجرای خودکار ربات...${NC}"
SERVICE_FILE="/etc/systemd/system/marzban-telegram-bot.service"
PROJECT_DIR=$(pwd)

sudo bash -c "cat > $SERVICE_FILE" << EOL
[Unit]
Description=ربات تلگرامی Marzban
After=network.target

[Service]
User=$SYSTEM_USER
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/venv/bin/python3 $PROJECT_DIR/main.py
Restart=always

[Install]
WantedBy=multi-user.target
EOL

if [ $? -eq 0 ]; then
    echo -e "${GREEN}فایل سرویس systemd با موفقیت ایجاد شد!${NC}"
else
    echo -e "${RED}خطا: نتوانستیم فایل سرویس systemd را ایجاد کنیم!${NC}"
    exit 1
fi

echo -e "${YELLOW}در حال فعال‌سازی و اجرای ربات...${NC}"
sudo systemctl daemon-reload
sudo systemctl enable marzban-telegram-bot
sudo systemctl start marzban-telegram-bot

if sudo systemctl is-active --quiet marzban-telegram-bot; then
    echo -e "${GREEN}ربات با موفقیت در پس‌زمینه اجرا شد!${NC}"
else
    echo -e "${RED}خطا: ربات اجرا نشد. لطفاً وضعیت سرویس را بررسی کنید:${NC}"
    echo -e "${YELLOW}دستور: sudo systemctl status marzban-telegram-bot${NC}"
    exit 1
fi

echo -e "${GREEN}نصب و اجرای خودکار با موفقیت به پایان رسید!${NC}"
echo -e "${YELLOW}نکات مهم:${NC}"
echo "1. برای بررسی وضعیت ربات:"
echo "   sudo systemctl status marzban-telegram-bot"
echo "2. برای توقف ربات:"
echo "   sudo systemctl stop marzban-telegram-bot"
echo "3. برای راه‌اندازی مجدد ربات:"
echo "   sudo systemctl restart marzban-telegram-bot"
echo "4. فایل تنظیمات (config.py) در مسیر پروژه قرار دارد."
echo "5. برای تست، ربات را در تلگرام با دستور /start اجرا کنید."