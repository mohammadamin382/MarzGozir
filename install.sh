#!/bin/bash

# رنگ‌ها برای خروجی
YELLOW='\033[1;33m'
NC='\033[0m'

INSTALL_DIR="/opt/marzgozir"
CONFIG_FILE="$INSTALL_DIR/bot_config.py"
COMPOSE_FILE="$INSTALL_DIR/docker-compose.yml"
REPO_URL="https://github.com/mahyyar/MarzGozir.git"

# تابع برای بررسی و نصب پیش‌نیازها
check_prerequisites() {
    if ! command -v git &> /dev/null; then
        echo -e "${YELLOW}Git نصب نیست. در حال نصب Git...${NC}"
        sudo apt-get update
        sudo apt-get install -y git || { echo "نصب Git شکست خورد"; exit 1; }
    fi
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Docker نصب نیست. در حال نصب Docker...${NC}"
        sudo apt-get update
        sudo apt-get install -y docker.io || { echo "نصب Docker شکست خورد"; exit 1; }
        sudo systemctl start docker
        sudo systemctl enable docker
    fi
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${YELLOW}Docker Compose نصب نیست. در حال نصب Docker Compose...${NC}"
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose || { echo "نصب Docker Compose شکست خورد"; exit 1; }
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
    echo "ADMIN_IDS=[$ADMIN_ID]" >> $CONFIG_FILE
    echo "DB_PATH=\"bot_data.db\"" >> $CONFIG_FILE
    echo "VERSION=\"v1.1.1\"" >> $CONFIG_FILE
    echo "CACHE_DURATION=300" >> $CONFIG_FILE
}

# تابع برای چک کردن فایل‌های لازم
check_required_files() {
    for file in Dockerfile docker-compose.yml requirements.txt main.py bot/handlers.py; do
        if [ ! -f "$INSTALL_DIR/$file" ]; then
            echo -e "${YELLOW}خطا: فایل $file پیدا نشد!${NC}"
            return 1
        fi
    done
    return 0
}

# تابع برای نصب ربات
install_bot() {
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}پوشه قبلی پیدا شد. در حال حذف پوشه و فایل‌های قدیمی...${NC}"
        sudo rm -rf $INSTALL_DIR
    fi
    
    check_prerequisites
    echo -e "${YELLOW}در حال کلون کردن مخزن از $REPO_URL...${NC}"
    git clone $REPO_URL $INSTALL_DIR || { echo "کلون کردن مخزن شکست خورد"; exit 1; }
    cd $INSTALL_DIR
    
    check_required_files || { echo "فایل‌های مورد نیاز وجود ندارند"; exit 1; }
    
    get_token_and_id || { echo "دریافت توکن و آیدی شکست خورد"; exit 1; }
    create_bot_config

    echo -e "${YELLOW}در حال ساخت و راه‌اندازی ربات با Docker Compose...${NC}"
    sudo docker-compose build --no-cache || { echo "ساخت تصویر Docker شکست خورد"; exit 1; }
    sudo docker-compose up -d || { echo "راه‌اندازی Docker Compose شکست خورد"; sudo docker-compose logs; exit 1; }
    echo -e "${YELLOW}ربات با موفقیت نصب شد و در حال اجرا است!${NC}"
}

# اجرای نصب ربات
install_bot || { echo -e "${YELLOW}نصب ربات با خطا مواجه شد. لطفاً خطاها را بررسی کنید.${NC}"; exit 1; }
