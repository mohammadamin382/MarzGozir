#!/bin/bash

# رنگ‌ها برای خروجی
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

INSTALL_DIR="/opt/marzgozir"
CONFIG_FILE="$INSTALL_DIR/bot_config.py"
COMPOSE_FILE="$INSTALL_DIR/docker-compose.yml"
REPO_URL="https://github.com/mahyyar/MarzGozir.git"

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
    echo -e "${YELLOW}لطفاً توکن ربات تلگرام را وارد کنید:${NC}"
    read BOT_TOKEN
    echo -e "${YELLOW}لطفاً آیدی عددی ادمین را وارد کنید (فقط عدد، بدون براکت):${NC}"
    read ADMIN_ID
    if [ -z "$BOT_TOKEN" ] || [ -z "$ADMIN_ID" ]; then
        echo -e "${YELLOW}خطا: توکن ربات و آیدی ادمین نمی‌توانند خالی باشند!${NC}"
        return 1
    fi
    if ! [[ "$ADMIN_ID" =~ ^[0-9]+$ ]]; then
        echo -e "${YELLOW}خطا: آیدی ادمین باید فقط عدد باشد!${NC}"
        return 1
    fi
    echo -e "${YELLOW}آیدی ادمین دریافت‌شده: $ADMIN_ID${NC}"
    return 0
}

# تابع برای ایجاد یا بازنویسی bot_config.py
create_bot_config() {
    echo -e "${YELLOW}در حال ایجاد یا بازنویسی فایل پیکربندی bot_config.py...${NC}"
    mkdir -p $INSTALL_DIR
    echo "TOKEN=\"$BOT_TOKEN\"" > $CONFIG_FILE
    echo "ADMIN_ID=[$ADMIN_ID]" >> $CONFIG_FILE
    echo "DB_PATH=\"bot_data.db\"" >> $CONFIG_FILE
    echo "VERSION=\"v1.1.1\"" >> $CONFIG_FILE
    echo "CACHE_DURATION=300" >> $CONFIG_FILE
}

# تابع برای چک کردن فایل‌های لازم
check_required_files() {
    for file in Dockerfile docker-compose.yml requirements.txt main.py; do
        if [ ! -f "$INSTALL_DIR/$file" ]; then
            echo -e "${YELLOW}خطا: فایل $file پیدا نشد!${NC}"
            return 1
        fi
    done
    return 0
}

# تابع برای نصب ربات
install_bot() {
    # بررسی اینکه آیا فایل‌های قبلی وجود دارند یا خیر
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}پوشه قبلی پیدا شد. در حال حذف پوشه و فایل‌های قدیمی...${NC}"
        sudo rm -rf $INSTALL_DIR
    fi
    
    # نصب پیش‌نیازها
    check_prerequisites
    
    # کلون کردن مخزن گیت و نصب
    echo -e "${YELLOW}در حال کلون کردن مخزن از $REPO_URL...${NC}"
    git clone $REPO_URL $INSTALL_DIR
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}خطا: کلون کردن مخزن شکست خورد!${NC}"
        return 1
    fi
    cd $INSTALL_DIR
    
    # چک کردن فایل‌های لازم
    check_required_files
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}خطا: برخی فایل‌های مورد نیاز وجود ندارند!${NC}"
        return 1
    fi
    
    # گرفتن توکن و آیدی ادمین از کاربر
    get_token_and_id
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}خطا در دریافت توکن و آیدی. لطفاً دوباره تلاش کنید.${NC}"
        return 1
    fi
    
    # ایجاد فایل پیکربندی
    create_bot_config

    # راه‌اندازی ربات با Docker
    echo -e "${YELLOW}در حال راه‌اندازی ربات با Docker Compose...${NC}"
    sudo docker-compose up -d
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}خطا: راه‌اندازی Docker Compose شکست خورد! لاگ‌ها را چک کنید:${NC}"
        sudo docker-compose logs
        return 1
    fi
    echo -e "${YELLOW}ربات با موفقیت نصب شد و در حال اجرا است!${NC}"
}

# اجرای نصب ربات
install_bot
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}نصب ربات با خطا مواجه شد. لطفاً خطاها را بررسی کنید.${NC}"
    exit 1
fi
