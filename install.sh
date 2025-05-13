#!/bin/bash

# رنگ‌ها برای خروجی
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# گرفتن توکن ربات و آیدی ادمین از کاربر
echo -e "${YELLOW}لطفاً توکن ربات تلگرام را وارد کنید:${NC}"
read -r BOT_TOKEN
echo -e "${YELLOW}لطفاً آیدی عددی ادمین را وارد کنید (فقط عدد، بدون براکت):${NC}"
read -r ADMIN_ID

# بررسی اینکه ورودی‌ها خالی نباشن
if [ -z "$BOT_TOKEN" ] || [ -z "$ADMIN_ID" ]; then
    echo -e "${YELLOW}خطا: توکن ربات و آیدی ادمین نمی‌توانند خالی باشند!${NC}"
    exit 1
fi

# بررسی اینکه آیدی ادمین فقط عدد باشه
if ! [[ "$ADMIN_ID" =~ ^[0-9]+$ ]]; then
    echo -e "${YELLOW}خطا: آیدی ادمین باید فقط عدد باشد!${NC}"
    exit 1
fi

# بررسی نصب بودن Docker
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Docker نصب نیست. در حال نصب Docker...${NC}"
    sudo apt-get update
    sudo apt-get install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
fi

# بررسی نصب بودن Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo -e "${YELLOW}Docker Compose نصب نیست. در حال نصب Docker Compose...${NC}"
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# تنظیم متغیرها
DOMAIN="your_domain.com" # دامنه خودتون رو جایگزین کنید
INSTALL_DIR="/opt/marzgozir"
CONFIG_FILE="$INSTALL_DIR/bot_config.py"

# کلون کردن ریپازیتوری
echo -e "${YELLOW}کلون کردن پروژه MarzGozir...${NC}"
sudo mkdir -p $INSTALL_DIR
sudo git clone https://github.com/mahyyar/MarzGozir.git $INSTALL_DIR
cd $INSTALL_DIR

# ایجاد یا به‌روزرسانی فایل bot_config.py
echo -e "${YELLOW}ایجاد یا به‌روزرسانی فایل bot_config.py...${NC}"
sudo cat <<EOL > $CONFIG_FILE
TOKEN = "$BOT_TOKEN"
ADMIN_ID = [$ADMIN_ID]
DB_PATH = "bot_data.db"
VERSION = "v1.1.1"
CACHE_DURATION = 300
EOL

# ایجاد فایل docker-compose.yml
echo -e "${YELLOW}ایجاد فایل docker-compose.yml...${NC}"
sudo cat <<EOL > docker-compose.yml
version: '3.8'
services:
  marzgozir:
    image: python:3.9
    container_name: marzgozir
    ports:
      - "8000:8000"
    volumes:
      - .:/app
      - /var/lib/marzgozir:/var/lib/marzgozir
    environment:
      - MARZBAN_DOMAIN=$DOMAIN
    working_dir: /app
    command: python3 main.py
    restart: unless-stopped
  telegram_bot:
    image: python:3.9
    container_name: marzgozir_bot
    volumes:
      - .:/app
      - /var/lib/marzgozir/bot_data:/app
    environment:
      - PYTHONPATH=/app
    working_dir: /app
    command: python3 bot.py
    restart: unless-stopped
volumes:
  marzgozir_data:
EOL

# نصب وابستگی‌های پایتون (اگر requirements.txt وجود داره)
if [ -f "requirements.txt" ]; then
    echo -e "${YELLOW}نصب وابستگی‌های پایتون...${NC}"
    sudo docker run --rm -v $(pwd):/app python:3.9 bash -c "pip install -r /app/requirements.txt"
fi

# راه‌اندازی سرویس با Docker Compose
echo -e "${YELLOW}راه‌اندازی MarzGozir و ربات با Docker Compose...${NC}"
sudo docker-compose up -d

# نمایش اطلاعات دسترسی
echo -e "${YELLOW}نصب با موفقیت انجام شد!${NC}"}"
