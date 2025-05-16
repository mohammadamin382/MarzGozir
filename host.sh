#!/bin/bash

YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
NC='\033[0m'

INSTALL_DIR="$HOME/marzgozir"
CONFIG_FILE="$INSTALL_DIR/bot_config.py"
DATA_DIR="$INSTALL_DIR/data"
DB_FILE="$DATA_DIR/bot_data.db"
REPO_URL="https://github.com/mahyyar/MarzGozir.git"
PYTHON="python3"
PIP="pip3"

check_prerequisites() {
    echo -e "${YELLOW}بررسی پیش‌نیازها...${NC}"
    command -v $PYTHON &> /dev/null || { echo -e "${RED}پایتون پیدا نشد! لطفاً پایتون ۳.۸ یا بالاتر نصب کنید${NC}"; exit 1; }
    command -v $PIP &> /dev/null || { echo -e "${RED}pip پیدا نشد! لطفاً pip نصب کنید${NC}"; exit 1; }
    command -v git &> /dev/null || { echo -e "${YELLOW}نصب Git...${NC}"; sudo apt-get update && sudo apt-get install -y git; } || { echo -e "${RED}نصب Git شکست خورد${NC}"; exit 1; }
    command -v curl &> /dev/null || { echo -e "${YELLOW}نصب Curl...${NC}"; sudo apt-get update && sudo apt-get install -y curl; } || { echo -e "${RED}نصب Curl شکست خورد${NC}"; exit 1; }
    echo -e "${GREEN}همه پیش‌نیازها آماده‌اند${NC}"
}

validate_token() {
    local token=$1
    echo -e "${YELLOW}اعتبارسنجی توکن تلگرام...${NC}"
    response=$(curl -s "https://api.telegram.org/bot${token}/getMe")
    if [[ "$response" =~ \"ok\":true ]]; then
        echo -e "${GREEN}توکن معتبر است${NC}"
        return 0
    else
        echo -e "${RED}توکن نامعتبر است! پاسخ: $response${NC}"
        return 1
    fi
}

get_token_and_id() {
    while true; do
        echo -e "${YELLOW}توکن ربات تلگرام رو وارد کنید:${NC}"
        read -r TOKEN
        echo -e "${YELLOW}آیدی عددی ادمین (فقط عدد) رو وارد کنید:${NC}"
        read -r ADMIN_ID
        if [[ -z "$TOKEN" || -z "$ADMIN_ID" ]]; then
            echo -e "${RED}توکن و آیدی ادمین نمی‌تونن خالی باشن!${NC}"
            continue
        fi
        if [[ ! "$TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
            echo -e "${RED}فرمت توکن اشتباهه! باید شبیه '123456789:ABCDEF...' باشه${NC}"
            continue
        fi
        if [[ ! "$ADMIN_ID" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}آیدی ادمین باید فقط عدد باشه!${NC}"
            continue
        fi
        if validate_token "$TOKEN"; then
            echo -e "${GREEN}توکن و آیدی ادمین ثبت شد${NC}"
            export TOKEN ADMIN_ID
            return 0
        else
            echo -e "${RED}لطفاً توکن معتبر وارد کنید${NC}"
        fi
    done
}

edit_bot_config() {
    echo -e "${YELLOW}ویرایش فایل bot_config.py...${NC}"
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${YELLOW}ایجاد فایل bot_config.py پیش‌فرض...${NC}"
        cat > "$CONFIG_FILE" << EOF
TOKEN = "SET_YOUR_TOKEN"
ADMIN_IDS = [123456789]
DB_PATH = "bot_data.db"
CACHE_DURATION = 30
VERSION = "V1.1.3"
EOF
    fi

    echo -e "${YELLOW}محتوای bot_config.py قبل از ویرایش:${NC}"
    cat "$CONFIG_FILE"

    ESCAPED_TOKEN=$(printf '%s' "$TOKEN" | sed -e 's/[\/&]/\\&/g')
    sed -i "s|^TOKEN\s*=\s*['\"].*['\"]|TOKEN = \"$ESCAPED_TOKEN\"|" "$CONFIG_FILE" || { echo -e "${RED}خطا در ویرایش TOKEN${NC}"; exit 1; }
    sed -i "s|^ADMIN_IDS\s*=\s*\[.*\]|ADMIN_IDS = [$ADMIN_ID]|" "$CONFIG_FILE" || { echo -e "${RED}خطا در ویرایش ADMIN_IDS${NC}"; exit 1; }
    chmod 644 "$CONFIG_FILE"

    echo -e "${YELLOW}محتوای bot_config.py بعد از ویرایش:${NC}"
    cat "$CONFIG_FILE"

    if grep -q "TOKEN = \"$ESCAPED_TOKEN\"" "$CONFIG_FILE" && grep -q "ADMIN_IDS = \[$ADMIN_ID\]" "$CONFIG_FILE"; then
        echo -e "${GREEN}فایل bot_config.py با موفقیت آپدیت شد${NC}"
    else
        echo -e "${RED}خطا: فایل bot_config.py درست آپدیت نشد${NC}"
        exit 1
    fi
}

setup_data_directory() {
    echo -e "${YELLOW}راه‌اندازی پوشه دیتابیس...${NC}"
    mkdir -p "$DATA_DIR"
    chmod 777 "$DATA_DIR"
    rm -f "$DB_FILE"
    echo -e "${GREEN}پوشه دیتابیس آماده شد${NC}"
}

install_dependencies() {
    echo -e "${YELLOW}نصب کتابخونه‌های پایتون...${NC}"
    if [[ -f "$INSTALL_DIR/requirements.txt" ]]; then
        $PIP install -r "$INSTALL_DIR/requirements.txt" || { echo -e "${RED}خطا در نصب کتابخونه‌ها${NC}"; exit 1; }
    else
        $PIP install aiogram || { echo -e "${RED}خطا در نصب aiogram${NC}"; exit 1; }
    fi
    echo -e "${GREEN}کتابخونه‌ها نصب شدند${NC}"
}

install_bot() {
    echo -e "${YELLOW}نصب ربات مرزگذیر...${NC}"
    if [[ -d "$INSTALL_DIR" ]]; then
        echo -e "${YELLOW}پوشه قبلی پیدا شد، حذف می‌شه...${NC}"
        rm -rf "$INSTALL_DIR" || { echo -e "${RED}خطا در حذف پوشه قبلی${NC}"; exit 1; }
    fi

    check_prerequisites
    echo -e "${YELLOW}کلون کردن پروژه از $REPO_URL...${NC}"
    git clone "$REPO_URL" "$INSTALL_DIR" || { echo -e "${RED}خطا در کلون کردن پروژه${NC}"; exit 1; }
    cd "$INSTALL_DIR" || { echo -e "${RED}خطا در ورود به پوشه پروژه${NC}"; exit 1; }

    get_token_and_id
    edit_bot_config
    setup_data_directory
    install_dependencies

    echo -e "${YELLOW}اجرای ربات...${NC}"
    nohup $PYTHON main.py > bot.log 2>&1 &
    sleep 3
    if ps aux | grep "[p]ython3 main.py" > /dev/null; then
        echo -e "${GREEN}ربات با موفقیت اجرا شد! لاگ‌ها در $INSTALL_DIR/bot.log${NC}"
    else
        echo -e "${RED}خطا در اجرای ربات! لاگ‌ها رو چک کنید:${NC}"
        cat "$INSTALL_DIR/bot.log"
        exit 1
    fi
}

update_bot() {
    echo -e "${YELLOW}آپدیت ربات...${NC}"
    if [[ ! -d "$INSTALL_DIR" ]]; then
        echo -e "${RED}ربات نصب نیست!${NC}"
        exit 1
    fi

    cd "$INSTALL_DIR" || exit 1
    [[ -f "$DB_FILE" ]] && cp "$DB_FILE" "/tmp/bot_data.db.bak" || true
    TOKEN=$(grep -E "^TOKEN\s*=" "$CONFIG_FILE" | sed -E "s/TOKEN\s*=\s*['\"]?([^'\"]+)['\"]?/\1/" | tr -d ' ')
    ADMIN_ID=$(grep -E "^ADMIN_IDS\s*=" "$CONFIG_FILE" | sed -E "s/ADMIN_IDS\s*=\s*\[(.*)\]/\1/" | tr -d ' ')
    
    if [[ ! "$TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ || ! "$ADMIN_ID" =~ ^[0-9]+$ ]] || ! validate_token "$TOKEN"; then
        echo -e "${RED}توکن یا آیدی ادمین نامعتبره، لطفاً دوباره وارد کنید${NC}"
        get_token_and_id
    fi

    rm -rf "$INSTALL_DIR" || { echo -e "${RED}خطا در حذف پوشه قبلی${NC}"; exit 1; }
    echo -e "${YELLOW}کلون کردن پروژه جدید...${NC}"
    git clone "$REPO_URL" "$INSTALL_DIR" || { echo -e "${RED}خطا در کلون کردن پروژه${NC}"; exit 1; }
    cd "$INSTALL_DIR" || exit 1

    [[ -f "/tmp/bot_data.db.bak" ]] && { mkdir -p "$DATA_DIR"; mv "/tmp/bot_data.db.bak" "$DB_FILE"; chmod 777 "$DATA_DIR"; }
    edit_bot_config
    install_dependencies

    echo -e "${YELLOW}اجرای ربات...${NC}"
    pkill -f "python3 main.py" 2>/dev/null || true
    nohup $PYTHON main.py > bot.log 2>&1 &
    sleep 3
    if ps aux | grep "[p]ython3 main.py" > /dev/null; then
        echo -e "${GREEN}ربات با موفقیت آپدیت و اجرا شد!${NC}"
    else
        echo -e "${RED}خطا در اجرای ربات! لاگ‌ها رو چک کنید:${NC}"
        cat "$INSTALL_DIR/bot.log"
        exit 1
    fi
}

show_menu() {
    clear
    echo -e "${YELLOW}===== منوی مدیریت ربات مرزگذیر =====${NC}"
    echo "1) نصب ربات"
    echo "2) آپدیت ربات"
    echo "3) خروج"
    echo -e "${YELLOW}یه گزینه انتخاب کنید (1-3):${NC}"
}

while true; do
    show_menu
    read -r choice
    case $choice in
        1) install_bot ;;
        2) update_bot ;;
        3) echo -e "${GREEN}خروج...${NC}"; exit 0 ;;
        *) echo -e "${RED}گزینه نامعتبر! لطفاً 1 تا 3 انتخاب کنید${NC}" ;;
    esac
    echo -e "${YELLOW}برای ادامه یه کلید بزنید...${NC}"
    read -n 1
done
