#!/bin/bash

# رنگ‌ها برای خروجی
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' 

INSTALL_DIR="/opt/marzgozir"
CONFIG_FILE="$INSTALL_DIR/bot_config.py"
COMPOSE_FILE="$INSTALL_DIR/docker-compose.yml"
REPO_URL="https://github.com/mahyyar/marzgozir.git"

# تابع برای بررسی و نصب پیش‌نیازها
check_prerequisites() {
    # بررسی و نصب git
    if ! command -v git &> /dev/null; then
        echo -e "${YELLOW}Git نصب نیست. در حال نصب Git...${NC}"
        sudo apt-get update
        sudo apt-get install -y git
    fi
    # بررسی و نصب Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Docker نصب نیست. در حال نصب Docker...${NC}"
        sudo apt-get update
        sudo apt-get install -y docker.io
        sudo systemctl start docker
        sudo systemctl enable docker
    fi
    # بررسی و نصب Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${YELLOW}Docker Compose نصب نیست. در حال نصب Docker Compose...${NC}"
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    fi
}

# تابع برای گرفتن توکن و آیدی
get_token_and_id() {
    read -p "$(echo -e ${YELLOW}لطفاً توکن ربات تلگرام را وارد کنید:${NC} )" BOT_TOKEN
    read -p "$(echo -e ${YELLOW}لطفاً آیدی عددی ادمین را وارد کنید (فقط عدد، بدون براکت):${NC} )" ADMIN_ID
    if [ -z "$BOT_TOKEN" ] || [ -z "$ADMIN_ID" ]; then
        echo -e "${YELLOW}خطا: توکن ربات و آیدی ادمین نمی‌توانند خالی باشند!${NC}"
        return 1
    fi
    if ! [[ "$ADMIN_ID" =~ ^[0-9]+$ ]]; then
        echo -e "${YELLOW}خطا: آیدی ادمین باید فقط عدد باشد!${NC}"
        return 1
    fi
    # دیباگ: نمایش آیدی برای اطمینان
    echo -e "${YELLOW}آیدی ادمین دریافت‌شده: $ADMIN_ID${NC}"
    return 0
}

# تابع برای ایجاد bot_config.py
create_bot_config() {
    echo -e "${YELLOW}در حال ایجاد یا به‌روزرسانی bot_config.py...${NC}"
    # دیباگ: نمایش مقادیر قبل از نوشتن (توکن مخفی می‌مونه)
    echo -e "${YELLOW}آیدی برای ذخیره: [$ADMIN_ID]${NC}"
    sudo cat <<EOL > $CONFIG_FILE
TOKEN = "$BOT_TOKEN"
ADMIN_ID = [$ADMIN_ID]
DB_PATH = "bot_data.db"
VERSION = "v1.1.1"
CACHE_DURATION = 300
EOL
    if [ $? -eq 0 ]; then
        echo -e "${YELLOW}فایل bot_config.py با موفقیت ساخته شد.${NC}"
    else
        echo -e "${YELLOW}خطا: ساخت فایل bot_config.py ناموفق بود.${NC}"
        return 1
    fi
}

# تابع برای نصب وابستگی‌ها
install_dependencies() {
    if [ -f "$INSTALL_DIR/requirements.txt" ]; then
        echo -e "${YELLOW}در حال نصب وابستگی‌های پایتون...${NC}"
        sudo docker run --rm -v $INSTALL_DIR:/app python:3.9 bash -c "pip install --no-cache-dir -r /app/requirements.txt"
        if [ $? -ne 0 ]; then
            echo -e "${YELLOW}خطا: نصب وابستگی‌ها ناموفق بود.${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}هشدار: فایل requirements.txt یافت نشد. مطمئن شوید وابستگی‌ها در پروژه وجود دارند.${NC}"
    fi
}

# تابع برای نصب ربات
install_bot() {
    check_prerequisites
    # حذف پروژه قبلی اگه وجود داره
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}پروژه قبلی یافت شد. در حال حذف...${NC}"
        sudo docker-compose -f $COMPOSE_FILE down -v 2>/dev/null
        sudo rm -rf $INSTALL_DIR
    fi
    # گرفتن توکن و آیدی
    get_token_and_id
    if [ $? -ne 0 ]; then
        return 1
    fi
    # کلون کردن ریپازیتوری
    echo -e "${YELLOW}در حال کلون کردن پروژه MarzGozir...${NC}"
    sudo mkdir -p /opt
    cd /opt
    sudo git clone $REPO_URL marzgozir
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}خطا: کلون کردن ریپازیتوری ناموفق بود. آدرس، دسترسی‌ها یا اتصال شبکه را بررسی کنید.${NC}"
        echo -e "${YELLOW}آدرس ریپازیتوری: $REPO_URL${NC}"
        sudo rm -rf $INSTALL_DIR
        return 1
    fi
    cd $INSTALL_DIR
    # ایجاد bot_config.py
    create_bot_config
    if [ $? -ne 0 ]; then
        return 1
    fi
    # نصب وابستگی‌ها
    install_dependencies
    if [ $? -ne 0 ]; then
        return 1
    fi
    # ایجاد docker-compose.yml
    echo -e "${YELLOW}در حال ایجاد docker-compose.yml...${NC}"
    sudo cat <<EOL > $COMPOSE_FILE
services:
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
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}خطا: ساخت فایل docker-compose.yml ناموفق بود.${NC}"
        return 1
    fi
    # راه‌اندازی سرویس‌ها
    echo -e "${YELLOW}در حال راه‌اندازی MarzGozir و ربات...${NC}"
    sudo docker-compose up -d
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}خطا: راه‌اندازی سرویس‌ها ناموفق بود. لاگ‌ها را با 'sudo docker-compose -f $COMPOSE_FILE logs' بررسی کنید.${NC}"
        return 1
    fi
    # نمایش اطلاعات
    echo -e "${YELLOW}نصب با موفقیت انجام شد!${NC}"
    echo -e "${YELLOW}ربات تلگرام باید فعال شده باشد. با توکن و آیدی تنظیم‌شده تست کنید.${NC}"
}

# تابع برای آپدیت ربات
update_bot() {
    if [ ! -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}خطا: پروژه نصب نشده است! ابتدا ربات را نصب کنید.${NC}"
        return 1
    fi
    cd $INSTALL_DIR
    echo -e "${YELLOW}در حال به‌روزرسانی پروژه MarzGozir...${NC}"
    sudo git pull
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}خطا: به‌روزرسانی ریپازیتوری ناموفق بود. دسترسی یا اتصال را بررسی کنید.${NC}"
        return 1
    fi
    install_dependencies
    if [ $? -ne 0 ]; then
        return 1
    fi
    echo -e "${YELLOW}در حال بازسازی و ری‌استارت سرویس‌ها...${NC}"
    sudo docker-compose up -d --build
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}خطا: بازسازی سرویس‌ها ناموفق بود. لاگ‌ها را با 'sudo docker-compose -f $COMPOSE_FILE logs' بررسی کنید.${NC}"
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
    echo -e "${YELLOW}در حال متوقف کردن و حذف سرویس‌ها...${NC}"
    sudo docker-compose down -v
    echo -e "${YELLOW}در حال حذف دایرکتوری پروژه...${NC}"
    sudo rm -rf $INSTALL_DIR
    echo -e "${YELLOW}ربات و تمام داده‌ها با موفقیت حذف شدند!${NC}"
}

# تابع برای ویرایش توکن و آیدی
edit_token_id() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}خطا: فایل bot_config.py یافت نشد! ابتدا ربات را نصب کنید.${NC}"
        return 1
    fi
    get_token_and_id
    if [ $? -ne 0 ]; then
        return 1
    fi
    create_bot_config
    if [ $? -ne 0 ]; then
        return 1
    fi
    cd $INSTALL_DIR
    echo -e "${YELLOW}در حال ری‌استارت سرویس ربات...${NC}"
    sudo docker-compose restart telegram_bot
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}خطا: ری‌استارت سرویس ربات ناموفق بود. لاگ‌ها را با 'sudo docker-compose -f $COMPOSE_FILE logs' بررسی کنید.${NC}"
        return 1
    fi
    echo -e "${YELLOW}توکن و آیدی ادمین با موفقیت به‌روزرسانی شدند!${NC}"
}

# منوی اصلی
while true; do
    clear
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}      منوی مدیریت MarzGozir  v0.3.0      ${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}1. نصب ربات${NC}"
    echo -e "${BLUE}2. آپدیت ربات${NC}"
    echo -e "${BLUE}3. حذف ربات${NC}"
    echo -e "${BLUE}4. ویرایش توکن و آیدی ادمین${NC}"
    echo -e "${BLUE}5. خروج${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${YELLOW}لطفاً یک گزینه انتخاب کنید (1-5):${NC}"
    read -r choice
    case $choice in
        1) install_bot ;;
        2) update_bot ;;
        3) remove_bot ;;
        4) edit_token_id ;;
        5) clear; echo -e "${YELLOW}در حال خروج از اسکریپت...${NC}"; exit 0 ;;
        *) echo -e "${YELLOW}گزینه نامعتبر! لطفاً یک عدد بین 1 تا 5 وارد کنید.${NC}" ;;
    esac
    echo -e "${YELLOW}برای ادامه، Enter بزنید...${NC}"
    read -r
done
