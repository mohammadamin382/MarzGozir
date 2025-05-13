#!/bin/bash

# رنگ‌ها برای خروجی
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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
ENV_FILE="$INSTALL_DIR/.env"

# کلون کردن ریپازیتوری
echo -e "${YELLOW}کلون کردن پروژه MarzGozir...${NC}"
sudo mkdir -p $INSTALL_DIR
sudo git clone https://github.com/mahyyar/MarzGozir.git $INSTALL_DIR
cd $INSTALL_DIR

# ایجاد فایل .env ساده (اگر پروژه نیاز به تنظیمات خاصی داره، باید اینجا اضافه بشه)
if [ ! -f $ENV_FILE ]; then
    echo -e "${YELLOW}ایجاد فایل تنظیمات .env...${NC}"
    cat <<EOL > $ENV_FILE
# تنظیمات پایه
MARZBAN_PORT=8000
MARZBAN_DOMAIN=$DOMAIN
# اگر دیتابیس یا تنظیمات دیگه‌ای نیازه، اینجا اضافه کنید
EOL
fi

# ایجاد فایل docker-compose.yml ساده
echo -e "${YELLOW}ایجاد فایل docker-compose.yml...${NC}"
cat <<EOL > docker-compose.yml
version: '3.8'
services:
  marzgozir:
    image: python:3.9 # تصویر پایه، اگر پروژه تصویر خاصی داره جایگزین کنید
    container_name: marzgozir
    ports:
      - "8000:8000"
    volumes:
      - .:/app
      - /var/lib/marzgozir:/var/lib/marzgozir
    environment:
      - MARZBAN_DOMAIN=$DOMAIN
    working_dir: /app
    command: python3 main.py # فرض می‌کنم پروژه یک main.py داره، اگر دستور دیگه‌ای نیازه اصلاح کنید
    restart: unless-stopped
volumes:
  marzgozir_data:
EOL

# راه‌اندازی سرویس با Docker Compose
echo -e "${YELLOW}راه‌اندازی MarzGozir با Docker Compose...${NC}"
sudo docker-compose up -d

# نمایش اطلاعات دسترسی
echo -e "${YELLOW}نصب با موفقیت انجام شد!${NC}"
