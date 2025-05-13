#!/bin/bash

# رنگ‌ها برای خروجی
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
NC='\033[0m'

INSTALL_DIR="/opt/marzgozir"
CONFIG_FILE="$INSTALL_DIR/bot_config.py"
COMPOSE_FILE="$INSTALL_DIR/docker-compose.yml"
DATA_DIR="$INSTALL_DIR/data"
REPO_URL="https://github.com/mahyyar/MarzGozir.git"

# تابع برای بررسی و نصب پیش‌نیازها
check_prerequisites() {
    echo -e "${YELLOW}بررسی پیش‌نیازها...${NC}"
    # بررسی Git
    if ! command -v git &> /dev/null; then
        echo -e "${YELLOW}Git نصب نیست. در حال نصب Git...${NC}"
        sudo apt-get update
        sudo apt-get install -y git || { echo -e "${RED}نصب Git شکست خورد${NC}"; exit 1; }
    fi
    # بررسی Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Docker نصب نیست. در حال نصب Docker...${NC}"
        sudo apt-get update
        sudo apt-get install -y docker.io || { echo -e "${RED}نصب Docker شکست خورد${NC}"; exit 1; }
        sudo systemctl start docker
        sudo systemctl enable docker
    fi
    # بررسی Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${YELLOW}Docker Compose نصب نیست. در حال نصب Docker Compose...${NC}"
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose || { echo -e "${RED}نصب Docker Compose شکست خورد${NC}"; exit 1; }
        sudo chmod +x /usr/local/bin/docker-compose
    fi
    echo -e "${GREEN}همه پیش‌نیازها نصب شدند${NC}"
}

# تابع برای گرفتن توکن و آیدی
get_token_and_id() {
    echo -e "${YELLOW}لطفاً توکن ربات تلگرام را وارد کنید:${NC}"
    read -r BOT_TOKEN
    echo -e "${YELLOW}لطفاً آیدی عددی ادمین را وارد کنید (فقط عدد، بدون براکت):${NC}"
    read -r ADMIN_ID
    if [ -z "$BOT_TOKEN" ] || [ -z "$ADMIN_ID" ]; then
        echo -e "${RED}خطا: توکن ربات و آیدی ادمین نمی‌توانند خالی باشند!${NC}"
        return 1
    fi
    if ! [[ "$ADMIN_ID" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}خطا: آیدی ادمین باید فقط عدد باشد!${NC}"
        return 1
    fi
    echo -e "${GREEN}توکن و آیدی ادمین دریافت شد${NC}"
    return 0
}

# تابع برای ایجاد یا بازنویسی bot_config.py
create_bot_config() {
    echo -e "${YELLOW}در حال ایجاد یا بازنویسی فایل پیکربندی bot_config.py...${NC}"
    mkdir -p "$INSTALL_DIR"
    {
        echo "TOKEN=\"$BOT_TOKEN\""
        echo "ADMIN_IDS=[$ADMIN_ID]"
        echo "DB_PATH=\"data/bot_data.db\""
        echo "VERSION=\"v1.1.1\""
        echo "CACHE_DURATION=300"
    } > "$CONFIG_FILE"
    chmod 644 "$CONFIG_FILE"
    echo -e "${GREEN}فایل bot_config.py با موفقیت ایجاد شد${NC}"
}

# تابع برای ایجاد پوشه دیتابیس و تنظیم مجوزها
setup_data_directory() {
    echo -e "${YELLOW}در حال ایجاد پوشه دیتابیس و تنظیم مجوزها...${NC}"
    mkdir -p "$DATA_DIR"
    chmod 777 "$DATA_DIR"
    # حذف فایل‌های قدیمی bot_data.db در مسیر اشتباه
    rm -f "$INSTALL_DIR/bot_data.db"
    echo -e "${GREEN}پوشه دیتابیس آماده شد${NC}"
}

# تابع برای چک کردن فایل‌های لازم
check_required_files() {
    echo -e "${YELLOW}بررسی فایل‌های مورد نیاز...${NC}"
    for file in Dockerfile docker-compose.yml requirements.txt main.py bot/handlers.py; do
        if [ ! -f "$INSTALL_DIR/$file" ]; then
            echo -e "${RED}خطا: فایل $file پیدا نشد!${NC}"
            return 1
        fi
    done
    echo -e "${GREEN}همه فایل‌های مورد نیاز موجود هستند${NC}"
    return 0
}

# تابع برای نصب ربات
install_bot() {
    # حذف پوشه قبلی اگه وجود داره
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}پوشه قبلی پیدا شد. در حال حذف پوشه و فایل‌های قدیمی...${NC}"
        sudo docker-compose -f "$COMPOSE_FILE" down 2>/dev/null || true
        sudo rm -rf "$INSTALL_DIR"
    fi
    
    # بررسی پیش‌نیازها
    check_prerequisites
    
    # کلون کردن مخزن
    echo -e "${YELLOW}در حال کلون کردن مخزن از $REPO_URL...${NC}"
    git clone "$REPO_URL" "$INSTALL_DIR" || { echo -e "${RED}کلون کردن مخزن شکست خورد${NC}"; exit 1; }
    cd "$INSTALL_DIR" || exit 1
    
    # بررسی فایل‌های مورد نیاز
    check_required_files || { echo -e "${RED}فایل‌های مورد نیاز وجود ندارند${NC}"; exit 1; }
    
    # گرفتن توکن و آیدی
    get_token_and_id || { echo -e "${RED}دریافت توکن و آیدی شکست خورد${NC}"; exit 1; }
    
    # ایجاد فایل پیکربندی و پوشه دیتابیس
    create_bot_config
    setup_data_directory

    # ساخت و راه‌اندازی ربات
    echo -e "${YELLOW}در حال ساخت و راه‌اندازی ربات با Docker Compose...${NC}"
    sudo docker-compose build --no-cache || { echo -e "${RED}ساخت تصویر Docker شکست خورد${NC}"; exit 1; }
    sudo docker-compose up -d || { echo -e "${RED}راه‌اندازی Docker Compose شکست خورد${NC}"; sudo docker-compose logs; exit 1; }
    echo -e "${GREEN}ربات با موفقیت نصب شد و در حال اجرا است!${NC}"
}

# اجرای نصب ربات
install_bot || { echo -e "${RED}نصب ربات با خطا مواجه شد. لطفاً خطاها را بررسی کنید.${NC}"; exit 1; }
