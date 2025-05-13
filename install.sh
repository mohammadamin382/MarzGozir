#!/bin/bash

# رنگ‌ها برای خروجی
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

# متغیرها
DOMAIN="your_domain.com" # دامنه خودتون رو جایگزین کنید
INSTALL_DIR="/opt/marzgozir"
CONFIG_FILE="$INSTALL_DIR/bot_config.py"
COMPOSE_FILE="$INSTALL_DIR/docker-compose.yml"
REPO_URL="https://github.com/mahyyar/marzgozir.git"

# تابع برای بررسی و نصب داکر
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Docker نصب نیست. در حال نصب Docker...${NC}"
        sudo apt-get update
        sudo apt-get install -y docker.io
        sudo systemctl start docker
        sudo systemctl enable docker
    fi
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${YELLOW}Docker Compose نصب نیست. در حال نصب Docker Compose...${NC}"
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    fi
}

# تابع برای گرفتن توکن و آیدی
get_token_and_id() {
    echo -e "${YELLOW}لطفاً توکن ربات تلگرام را وارد کنید:${NC}"
    read -r BOT_TOKEN
    echo -e "${YELLOW}لطفاً آیدی عددی ادمین را وارد کنید (فقط عدد، بدون براکت):${NC}"
    read -r ADMIN_ID
    if [ -z "$BOT_TOKEN" ] || [ -z "$ADMIN_ID" ]; then
        echo -e "${YELLOW}خطا: توکن ربات و آیدی ادمین نمی‌توانند خالی باشند!${NC}"
        return 1
    fi
    if ! [[ "$ADMIN_ID" =~ ^[0-9]+$ ]]; then
        echo -e "${YELLOW}خطا: آیدی ادمین باید فقط عدد باشد!${NC}"
        return 1
    fi
    echo "$BOT_TOKEN" "$ADMIN_ID"
    return 0
}

# تابع برای ایجاد bot_config.py
create_bot_config() {
    local BOT_TOKEN="$1"
    local ADMIN_ID="$2"
    echo -e "${YELLOW}ایجاد یا به‌روزرسانی فایل bot_config.py...${NC}"
    sudo cat <<EOL > $CONFIG_FILE
TOKEN = "$BOT_TOKEN"
ADMIN_ID = [$ADMIN_ID]
DB_PATH = "bot_data.db"
VERSION = "v1.1.1"
CACHE_DURATION = 300
EOL
}

# تابع برای نصب وابستگی‌ها
install_dependencies() {
    if [ -f "$INSTALL_DIR/requirements.txt" ]; then
        echo -e "${YELLOW}نصب وابستگی‌های پایتون...${NC}"
        sudo docker run --rm -v $INSTALL_DIR:/app python:3.9 bash -c "pip install --no-cache-dir -r /app/requirements.txt"
    else
        echo -e "${YELLOW}هشدار: فایل requirements.txt یافت نشد. مطمئن شوید وابستگی‌ها در پروژه وجود دارند.${NC}"
    fi
}

# تابع برای نصب ربات
install_bot() {
    check_docker
    # حذف پروژه قبلی اگه وجود داره
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}پروژه قبلی یافت شد. در حال حذف...${NC}"
        cd $INSTALL_DIR
        sudo docker-compose down -v 2>/dev/null
        sudo rm -rf $INSTALL_DIR
    fi
    # گرفتن توکن و آیدی
    read -r BOT_TOKEN ADMIN_ID < <(get_token_and_id)
    if [ $? -ne 0 ]; then
        return 1
    fi
    # کلون کردن ریپازیتوری
    echo -e "${YELLOW}کلون کردن پروژه MarzGozir...${NC}"
    sudo mkdir -p $INSTALL_DIR
    sudo git clone $REPO_URL $INSTALL_DIR
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}خطا: کلون کردن ریپازیتوری ناموفق بود. آدرس یا دسترسی را بررسی کنید.${NC}"
        sudo rm -rf $INSTALL_DIR
        return 1
    fi
    cd $INSTALL_DIR
    # ایجاد bot_config.py
    create_bot_config "$BOT_TOKEN" "$ADMIN_ID"
    # نصب وابستگی‌ها
    install_dependencies
    # ایجاد docker-compose.yml
    echo -e "${YELLOW}ایجاد فایل docker-compose.yml...${NC}"
    sudo cat <<EOL > $COMPOSE_FILE
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
    command: bash -c "pip install --no-cache-dir -r requirements.txt && python3 main.py"
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
    command: bash -c "pip install --no-cache-dir -r requirements.txt && python3 bot.py"
    restart: unless-stopped
volumes:
  marzgozir_data:
EOL
    # راه‌اندازی سرویس‌ها
    echo -e "${YELLOW}راه‌اندازی MarzGozir و ربات...${NC}"
    sudo docker-compose up -d
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}خطا: راه‌اندازی سرویس‌ها ناموفق بود. لاگ‌ها را بررسی کنید.${NC}"
        return 1
    fi
    # نمایش اطلاعات
    echo -e "${YELLOW}نصب با موفقیت انجام شد!${NC}"
    echo -e "- داشبورد (اگر فعال باشه): https://$DOMAIN:8000/dashboard/"
    echo -e "${YELLOW}اگر SSL کار نکرد، از http://$DOMAIN:8000/dashboard/ یا IP سرور استفاده کنید.${NC}"
    echo -e "${YELLOW}ربات تلگرام باید فعال شده باشد. با توکن و آیدی تنظیم‌شده تست کنید.${NC}"
}

# تابع برای آپدیت ربات
update_bot() {
    if [ ! -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}خطا: پروژه نصب نشده است! ابتدا ربات را نصب کنید.${NC}"
        return 1
    fi
    cd $INSTALL_DIR
    echo -e "${YELLOW}به‌روزرسانی پروژه MarzGozir...${NC}"
    sudo git pull
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}خطا: به‌روزرسانی ریپازیتوری ناموفق بود. دسترسی یا اتصال را بررسی کنید.${NC}"
        return 1
    fi
    install_dependencies
    echo -e "${YELLOW}بازسازی و ری‌استارت سرویس‌ها...${NC}"
    sudo docker-compose up -d --build
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}خطا: بازسازی سرویس‌ها ناموفق بود. لاگ‌ها را بررسی کنید.${NC}"
        return 1
    fi
    echo -e "${YELLOW}ربات با موفقیت آپدیت شد!${NC}"
}

# تابع برای حذف ربات
remove_bot() {
    if [ ! -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}خطا: پروژه نصب نشده است!${NC}"
        return 1
    fi
    cd $INSTALL_DIR
    echo -e "${YELLOW}متوقف کردن و حذف سرویس‌ها...${NC}"
    sudo docker-compose down -v
    echo -e "${YELLOW}حذف دایرکتوری پروژه...${NC}"
    sudo rm -rf $INSTALL_DIR
    echo -e "${YELLOW}ربات و تمام داده‌ها با موفقیت حذف شدند!${NC}"
}

# تابع برای ویرایش توکن و آیدی
edit_token_id() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}خطا: فایل bot_config.py یافت نشد! ابتدا ربات را نصب کنید.${NC}"
        return 1
    fi
    read -r BOT_TOKEN ADMIN_ID < <(get_token_and_id)
    if [ $? -ne 0 ]; then
        return 1
    fi
    create_bot_config "$BOT_TOKEN" "$ADMIN_ID"
    cd $INSTALL_DIR
    echo -e "${YELLOW}ری‌استارت سرویس ربات...${NC}"
    sudo docker-compose restart telegram_bot
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}خطا: ری‌استارت سرویس ربات ناموفق بود. لاگ‌ها را بررسی کنید.${NC}"
        return 1
    fi
    echo -e "${YELLOW}توکن و آیدی با موفقیت ویرایش شدند!${NC}"
}

# منوی اصلی
while true; do
    clear
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}      MarzGozir Management Menu      ${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}1. Install Bot${NC}"
    echo -e "${BLUE}2. Update Bot${NC}"
    echo -e "${BLUE}3. Remove Bot${NC}"
    echo -e "${BLUE}4. Edit Token and Admin ID${NC}"
    echo -e "${BLUE}5. Exit${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${YELLOW}Please select an option (1-5):${NC}"
    read -r choice
    case $choice in
        1) install_bot ;;
        2) update_bot ;;
        3) remove_bot ;;
        4) edit_token_id ;;
        5) clear; echo -e "${YELLOW}خروج از اسکریپت...${NC}"; exit 0 ;;
        *) echo -e "${YELLOW}گزینه نامعتبر! لطفاً یک عدد بین 1 تا 5 وارد کنید.${NC}" ;;
    esac
    echo -e "${YELLOW}برای ادامه، Enter بزنید...${NC}"
    read -r
done
