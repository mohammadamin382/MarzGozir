#!/bin/bash

# اسکریپت نصب خودکار MarzGozir
# نصب پیش‌نیازها، قرار دادن سورس در /opt/MarzGozir، اجرای پروژه با Docker
# حفظ قابلیت‌های CLI: نصب بات، آپدیت بات، حذف بات، ویرایش توکن و آیدی، خروج
# اصلاح خطای افزودن کاربر به گروه docker

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

# 1. به‌روزرسانی سیستم و نصب ابزارهای اولیه
echo -e "${GREEN}به‌روزرسانی سیستم و نصب ابزارها...${NC}"
apt update && apt upgrade -y
apt install -y curl wget git python3 python3-pip
check_error "نصب ابزارهای اولیه ناموفق بود"

# 2. نصب Docker
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
echo -e "${GREEN}افزودن کاربر به گروه docker...${NC}"
# بررسی وجود گروه docker
if ! getent group docker > /dev/null; then
  echo -e "${YELLOW}گروه docker وجود ندارد. ایجاد گروه...${NC}"
  groupadd docker
  check_error "ایجاد گروه docker ناموفق بود"
fi

# استفاده از USER_NAME به جای SUDO_USER برای اطمینان
USER_NAME=${SUDO_USER:-$(whoami)}
if [ -z "$USER_NAME" ] || [ "$USER_NAME" == "root" ]; then
  echo -e "${YELLOW}کاربر معتبر یافت نشد. استفاده از کاربر پیش‌فرض (nobody)...${NC}"
  USER_NAME="nobody"
fi
usermod -aG docker "$USER_NAME"
check_error "افزودن کاربر $USER_NAME به گروه docker ناموفق بود"

# 3. نصب Docker Compose
echo -e "${GREEN}نصب Docker Compose...${NC}"
if ! command -v docker-compose &> /dev/null; then
  pip3 install docker-compose
  check_error "نصب Docker Compose ناموفق بود"
else
  echo -e "${YELLOW}Docker Compose قبासاً نصب شده است${NC}"
fi

# 4. ایجاد پوشه و کلون کردن پروژه در /opt/MarzGozir
echo -e "${GREEN}کلون کردن MarzGozir در /opt/MarzGozir...${NC}"
if [ -d "/opt/MarzGozir" ]; then
  echo -e "${YELLOW}پوشه /opt/MarzGozir وجود دارد. حذف و کلون مجدد...${NC}"
  rm -rf /opt/MarzGozir
fi
git clone https://github.com/mahyyar/MarzGozir.git /opt/MarzGozir
check_error "کلون پروژه ناموفق بود"
cd /opt/MarzGozir

# 5. نصب وابستگی‌های پایتون
echo -e "${GREEN}نصب وابستگی‌های پایتون...${NC}"
pip3 install -r requirements.txt
check_error "نصب وابستگی‌ها ناموفق بود"

# 6. ایجاد فایل .env نمونه
echo -e "${GREEN}ایجاد فایل .env نمونه...${NC}"
if [ -f ".env.example" ]; then
  cp .env.example .env
  # تنظیمات پیش‌فرض برای نمونه
  cat <<EOL >> .env
# تنظیمات نمونه اولیه
ADMIN_USERNAME=admin
ADMIN_PASSWORD=admin123
DOMAIN=your_domain.com
SSL_ENABLED=false
TELEGRAM_BOT_TOKEN=your_bot_token
TELEGRAM_ADMIN_ID=your_admin_id
DATABASE_URL=sqlite:///db.sqlite3
EOL
  echo -e "${YELLOW}فایل .env ایجاد شد. لطفاً دامنه، توکن بات، و آیدی ادمین را در /opt/MarzGozir/.env ویرایش کنید.${NC}"
else
  echo -e "${RED}فایل .env.example یافت نشد!${NC}"
  exit 1
fi

# 7. اجرای مهاجرت‌های پایگاه داده
echo -e "${GREEN}اجرای مهاجرت‌های پایگاه داده...${NC}"
python3 manage.py migrate
check_error "اجرای مهاجرت‌ها ناموفق بود"

# 8. اجرای پروژه با Docker Compose
echo -e "${GREEN}اجرای پروژه با Docker Compose...${NC}"
docker-compose up -d
check_error "اجرای Docker Compose ناموفق بود"

# 9. تنظیم CLI برای حفظ قابلیت‌های اصلی
echo -e "${GREEN}تنظیم CLI پروژه...${NC}"
if [ -f "marzban-cli.py" ]; then
  ln -s /opt/MarzGozir/marzban-cli.py /usr/bin/marzban-cli
  chmod +x /usr/bin/marzban-cli
  marzban-cli completion install
  echo -e "${GREEN}CLI نصب شد. می‌توانید از دستورات زیر استفاده کنید:${NC}"
  echo -e "  - نصب بات: marzban-cli bot install"
  echo -e "  - آپدیت بات: marzban-cli bot update"
  echo -e "  - حذف بات: marzban-cli bot remove"
  echo -e "  - ویرایش توکن و آیدی: ویرایش /opt/MarzGozir/.env"
  echo -e "  - خروج: marzban-cli logout"
else
  echo -e "${YELLOW}فایل marzban-cli.py یافت نشد. قابلیت‌های CLI ممکن است محدود باشد.${NC}"
fi

# 10. نمایش اطلاعات نهایی
echo -e "${GREEN}نصب و اجرا با موفقیت انجام شد!${NC}"
echo -e "${YELLOW}جزئیات:${NC}"
echo -e "- داشبورد: http://your_domain.com:8000/dashboard/"
echo -e "- فایل تنظیمات: /opt/MarzGozir/.env"
echo -e "- مدیریت سرویس:"
echo -e "  توقف: cd /opt/MarzGozir && docker-compose down"
echo -e "  راه‌اندازی مجدد: cd /opt/MarzGozir && docker-compose up -d"
echo -e "- دستورات CLI: marzban-cli --help"
echo -e "${YELLOW}برای امنیت، SSL را فعال کنید و .env را ویرایش کنید.${NC}"
