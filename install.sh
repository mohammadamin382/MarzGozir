#!/bin/bash

# اسکریپت نصب خودکار MarzGozir
# نصب پیش‌نیازها، قرار دادن سورس در /opt/MarzGozir، اجرای پروژه با Docker
# حفظ قابلیت‌های CLI: نصب بات، آپدیت بات، حذف بات، ویرایش توکن و آیدی، خروج
# دریافت توکن و آیدی از کاربر و ذخیره در bot_config.py
# اصلاح خطای نصب Docker Compose با روش مقاوم‌تر

# رنگ‌ها برای خروجی
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# بررسی دسترسی root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}لطفاً اسکریپت را با sudo اجرا کنید${NC}"
  exit 1
fi

# تابع بررسی خطا
check_error() {
  if [ $? -ne 0 ]; then
    echo -e "${RED}خطا: $1${NC}"
    exit 1
  fi
}

echo -e "${YELLOW}نصب و اجرای MarzGozir...${NC}"

# 1. دریافت توکن و آیدی از کاربر
echo -e "${GREEN}لطفاً اطلاعات بات تلگرام را وارد کنید:${NC}"
read -p "توکن بات تلگرام (TELEGRAM_BOT_TOKEN): " TELEGRAM_BOT_TOKEN
if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
  echo -e "${RED}توکن نمی‌تواند خالی باشد!${NC}"
  exit 1
fi
read -p "آیدی عددی ادمین (TELEGRAM_ADMIN_ID): " TELEGRAM_ADMIN_ID
if [ -z "$TELEGRAM_ADMIN_ID" ]; then
  echo -e "${RED}آیدی نمی‌تواند خالی باشد!${NC}"
  exit 1
fi

# 2. دریافت نام کاربر برای گروه docker
echo -e "${GREEN}لطفاً نام کاربری سیستم را وارد کنید (برای افزودن به گروه docker):${NC}"
read -p "نام کاربر (یا Enter برای استفاده از کاربر فعلی): " INPUT_USER
if [ -z "$INPUT_USER" ]; then
  USER_NAME=$(who -u | awk '{print $1}' | head -n 1)
else
  USER_NAME="$INPUT_USER"
fi
if [ -z "$USER_NAME" ] || [ "$USER_NAME" == "root" ]; then
  echo -e "${YELLOW}کاربر معتبر یافت نشد. استفاده از کاربر پیش‌فرض (nobody)...${NC}"
  USER_NAME="nobody"
fi
# بررسی وجود کاربر
if ! id "$USER_NAME" >/dev/null 2>&1; then
  echo -e "${RED}کاربر $USER_NAME وجود ندارد!${NC}"
  exit 1
fi

# 3. به‌روزرسانی سیستم و نصب ابزارهای اولیه
echo -e "${GREEN}به‌روزرسانی سیستم و نصب ابزارها...${NC}"
apt update && apt upgrade -y
apt install -y curl wget git python3 python3-pip python3-venv
check_error "نصب ابزارهای اولیه ناموفق بود"

# 4. نصب Docker
echo -e "${GREEN}نصب Docker...${NC}"
if ! command -v docker &> /dev/null; then
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
  check_error "نصب Docker ناموفق بود"
  rm get-docker.sh
else
  echo -e "${YELLOW}Docker قبلاً نصب شده است${NC}"
fi

# بررسی و افزودن کاربر به گروه docker
echo -e "${GREEN}افزودن کاربر $USER_NAME به گروه docker...${NC}"
if ! getent group docker > /dev/null; then
  echo -e "${YELLOW}گروه docker وجود ندارد. ایجاد گروه...${NC}"
  groupadd docker
  check_error "ایجاد گروه docker ناموفق بود"
fi
usermod -aG docker "$USER_NAME"
check_error "افزودن کاربر $USER_NAME به گروه docker ناموفق بود"

# 5. نصب Docker Compose
echo -e "${GREEN}نصب Docker Compose...${NC}"
if ! command -v docker-compose &> /dev/null; then
  # تلاش برای نصب از طریق باینری
  DOCKER_COMPOSE_VERSION="2.29.7" # نسخه به‌روز
  ARCH=$(uname -m)
  case $ARCH in
    x86_64) ARCH="x86_64" ;;
    aarch64) ARCH="aarch64" ;;
    *) echo -e "${RED}معماری $ARCH پشتیبانی نمی‌شود!${NC}"; exit 1 ;;
  esac
  curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-${ARCH}" -o /usr/local/bin/docker-compose
  if [ $? -ne 0 ]; then
    echo -e "${YELLOW}دانلود باینری Docker Compose ناموفق بود. تلاش برای نصب از apt...${NC}"
    apt install -y docker-compose
    check_error "نصب Docker Compose از apt ناموفق بود"
  else
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    check_error "نصب Docker Compose ناموفق بود"
  fi
else
  echo -e "${YELLOW}Docker Compose قبلاً نصب شده است${NC}"
fi
# بررسی نصب موفقیت‌آمیز
if ! command -v docker-compose &> /dev/null; then
  echo -e "${RED}Docker Compose نصب نشد!${NC}"
  exit 1
fi
echo -e "${GREEN}نسخه Docker Compose: $(docker-compose --version)${NC}"

# 6. ایجاد پوشه و کلون کردن پروژه در /opt/MarzGozir
echo -e "${GREEN}کلون کردن MarzGozir در /opt/MarzGozir...${NC}"
if [ -d "/opt/MarzGozir" ]; then
  echo -e "${YELLOW}پوشه /opt/MarzGozir وجود دارد. حذف و کلون مجدد...${NC}"
  rm -rf /opt/MarzGozir
fi
git clone https://github.com/mahyyar/MarzGozir.git /opt/MarzGozir
check_error "کلون پروژه ناموفق بود"
cd /opt/MarzGozir

# 7. ایجاد یا به‌روزرسانی فایل bot_config.py
echo -e "${GREEN}ایجاد/به‌روزرسانی فایل bot_config.py...${NC}"
cat <<EOL > bot_config.py
# تنظیمات بات تلگرام
TOKEN = "$TELEGRAM_BOT_TOKEN"
ADMIN_ID = "$TELEGRAM_ADMIN_ID"
EOL
check_error "ایجاد فایل bot_config.py ناموفق بود"

# 8. نصب وابستگی‌های پایتون در محیط مجازی
echo -e "${GREEN}نصب وابستگی‌های پایتون در محیط مجازی...${NC}"
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
check_error "نصب وابستگی‌ها ناموفق بود"
deactivate

# 9. ایجاد فایل .env نمونه
echo -e "${GREEN}ایجاد فایل .env نمونه...${NC}"
if [ -f ".env.example" ]; then
  cp .env.example .env
  cat <<EOL >> .env
# تنظیمات نمونه اولیه
ADMIN_USERNAME=admin
ADMIN_PASSWORD=admin123
DOMAIN=your_domain.com
SSL_ENABLED=false
DATABASE_URL=sqlite:///db.sqlite3
EOL
  echo -e "${YELLOW}فایل .env ایجاد شد. لطفاً دامنه را در /opt/MarzGozir/.env ویرایش کنید.${NC}"
else
  echo -e "${RED}فایل .env.example یافت نشد!${NC}"
  exit 1
fi

# 10. اجرای مهاجرت‌های پایگاه داده
echo -e "${GREEN}اجرای مهاجرت‌های پایگاه داده...${NC}"
source venv/bin/activate
python3 manage.py migrate
check_error "اجرای مهاجرت‌ها ناموفق بود"
deactivate

# 11. اجرای پروژه با Docker Compose
echo -e "${GREEN}اجرای پروژه با Docker Compose...${NC}"
docker-compose up -d
check_error "اجرای Docker Compose ناموفق بود"

# 12. تنظیم CLI برای حفظ قابلیت‌های اصلی
echo -e "${GREEN}تنظیم CLI پروژه...${NC}"
if [ -f "marzban-cli.py" ]; then
  ln -s /opt/MarzGozir/marzban-cli.py /usr/bin/marzban-cli
  chmod +x /usr/bin/marzban-cli
  source venv/bin/activate
  marzban-cli completion install
  deactivate
  echo -e "${GREEN}CLI نصب شد. می‌توانید از دستورات زیر استفاده کنید:${NC}"
  echo -e "  - نصب بات: marzban-cli bot install"
  echo -e "  - آپدیت بات: marzban-cli bot update"
  echo -e "  - حذف بات: marzban-cli bot remove"
  echo -e "  - ویرایش توکن و آیدی: ویرایش /opt/MarzGozir/bot_config.py"
  echo -e "  - خروج: marzban-cli logout"
else
  echo -e "${YELLOW}فایل marzban-cli.py یافت نشد. قابلیت‌های CLI ممکن است محدود باشد.${NC}"
fi

# 13. نمایش اطلاعات نهایی
echo -e "${GREEN}نصب و اجرا با موفقیت انجام شد!${NC}"
echo -e "${YELLOW}جزئیات:${NC}"
echo -e "- داشبورد: http://your_domain.com:8000/dashboard/"
echo -e "- فایل تنظیمات: /opt/MarzGozir/.env"
echo -e "- تنظیمات بات: /opt/MarzGozir/bot_config.py"
echo -e "- مدیریت سرویس:"
echo -e "  توقف: cd /opt/MarzGozir && docker-compose down"
echo -e "  راه‌اندازی مجدد: cd /opt/MarzGozir && docker-compose up -d"
echo -e "- دستورات CLI: marzban-cli --help"
echo -e "${YELLOW}برای امنیت، SSL را فعال کنید و .env را ویرایش کنید.${NC}"
