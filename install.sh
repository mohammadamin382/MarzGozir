#!/bin/bash

YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
NC='\033[0m'

INSTALL_DIR="/opt/marzgozir"
CONFIG_FILE="$INSTALL_DIR/bot_config.py"
COMPOSE_FILE="$INSTALL_DIR/docker-compose.yml"
DATA_DIR="$INSTALL_DIR/data"
REPO_URL="https://github.com/mahyyar/MarzGozir.git"

check_prerequisites() {
    echo -e "${YELLOW}بررسی پیش‌نیازها...${NC}"
    if ! command -v git &> /dev/null; then
        echo -e "${YELLOW}Git نصب نیست. در حال نصب Git...${NC}"
        sudo apt-get update
        sudo apt-get install -y git || { echo -e "${RED}نصب Git شکست خورد${NC}"; exit 1; }
    fi
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Docker نصب نیست. در حال نصب Docker...${NC}"
        sudo apt-get update
        sudo apt-get install -y docker.io || { echo -e "${RED}نصب Docker شکست خورد${NC}"; exit 1; }
        sudo systemctl start docker
        sudo systemctl enable docker
    fi
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${YELLOW}Docker Compose نصب نیست. در حال نصب Docker Compose...${NC}"
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose || { echo -e "${RED}نصب Docker Compose شکست خورد${NC}"; exit 1; }
        sudo chmod +x /usr/local/bin/docker-compose
    fi
    echo -e "${GREEN}همه پیش‌نیازها نصب شدند${NC}"
}

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

setup_data_directory() {
    echo -e "${YELLOW}در حال ایجاد پوشه دیتابیس و تنظیم مجوزها...${NC}"
    mkdir -p "$DATA_DIR"
    chmod 777 "$DATA_DIR"
    rm -f "$INSTALL_DIR/bot_data.db"
    echo -e "${GREEN}پوشه دیتابیس آماده شد${NC}"
}

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

install_bot() {
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}پوشه قبلی پیدا شد. در حال حذف پوشه و فایل‌های قدیمی...${NC}"
        sudo docker-compose -f "$COMPOSE_FILE" down 2>/dev/null || true
        sudo rm -rf "$INSTALL_DIR"
    fi
    check_prerequisites
    echo -e "${YELLOW}در حال کلون کردن مخزن از $REPO_URL...${NC}"
    git clone "$REPO_URL" "$INSTALL_DIR" || { echo -e "${RED}کلون کردن مخزن شکست خورد${NC}"; exit 1; }
    cd "$INSTALL_DIR" || exit 1
    check_required_files || { echo -e "${RED}فایل‌های مورد نیاز وجود ندارند${NC}"; exit 1; }
    get_token_and_id || { echo -e "${RED}دریافت توکن و آیدی شکست خورد${NC}"; exit 1; }
    create_bot_config
    setup_data_directory
    echo -e "${YELLOW}در حال ساخت و راه‌اندازی ربات با Docker Compose...${NC}"
    sudo docker-compose build --no-cache || { echo -e "${RED}ساخت تصویر Docker شکست خورد${NC}"; exit 1; }
    sudo docker-compose up -d || { echo -e "${RED}راه‌اندازی Docker Compose شکست خورد${NC}"; sudo docker-compose logs; exit 1; }
    echo -e "${GREEN}ربات با موفقیت نصب شد و در حال اجرا است!${NC}"
}

uninstall_bot() {
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}در حال توقف و حذف ربات...${NC}"
        cd "$INSTALL_DIR" || exit 1
        sudo docker-compose -f "$COMPOSE_FILE" down 2>/dev/null || true
        sudo rm -rf "$INSTALL_DIR"
        echo -e "${GREEN}ربات با موفقیت حذف شد${NC}"
    else
        echo -e "${RED}ربات نصب نشده است!${NC}"
    fi
}

restart_bot() {
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}در حال ری‌استارت کردن ربات...${NC}"
        cd "$INSTALL_DIR" || exit 1
        sudo docker-compose -f "$COMPOSE_FILE" restart || { echo -e "${RED}ری‌استارت کردن ربات شکست خورد${NC}"; exit 1; }
        echo -e "${GREEN}ربات با موفقیت ری‌استارت شد${NC}"
    else
        echo -e "${RED}ربات نصب نشده است!${NC}"
    fi
}

reset_token_and_id() {
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}در حال تنظیم مجدد توکن و آیدی...${NC}"
        get_token_and_id || { echo -e "${RED}دریافت توکن و آیدی شکست خورد${NC}"; exit 1; }
        create_bot_config
        restart_bot
    else
        echo -e "${RED}فایل پیکربندی یافت نشد! لطفاً ابتدا ربات را نصب کنید.${NC}"
    fi
}

clear_project() {
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}در حال پاک کردن پروژه...${NC}"
        cd "$INSTALL_DIR" || exit 1
        sudo docker-compose -f "$COMPOSE_FILE" down 2>/dev/null || true
        sudo rm -rf "$INSTALL_DIR"
        echo -e "${GREEN}پروژه با موفقیت پاک شد${NC}"
    else
        echo -e "${RED}پروژه‌ای برای پاک کردن وجود ندارد!${NC}"
    fi
}

show_menu() {
    clear
    echo -e "${YELLOW}=== منوی مدیریت ربات ===${NC}"
    echo "1) نصب بات"
    echo "2) حذف بات"
    echo "3) ری‌استارت کردن بات"
    echo "4) تنظیم مجدد توکن و آیدی عددی"
    echo "5) پاک کردن پروژه"
    echo "6) خارج شدن"
    echo -e "${YELLOW}لطفاً یک گزینه را انتخاب کنید (1-6):${NC}"
}

while true; do
    show_menu
    read -r choice
    case $choice in
        1) install_bot ;;
        2) uninstall_bot ;;
        3) restart_bot ;;
        4) reset_token_and_id ;;
        5) clear_project ;;
        6) echo -e "${GREEN}خروج از برنامه${NC}"; exit 0 ;;
        *) echo -e "${RED}گزینه نامعتبر! لطفاً یک عدد بین 1 تا 6 وارد کنید.${NC}" ;;
    esac
    echo -e "${YELLOW}برای بازگشت به منو، هر کلید را فشار دهید...${NC}"
    read -n 1
done
