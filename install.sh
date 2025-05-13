#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run with sudo${NC}"
  exit 1
fi

check_error() {
  if [ $? -ne 0 ]; then
    echo -e "${RED}Error: $1${NC}"
    exit 1
  fi
}

echo -e "${YELLOW}Installing and running MarzGozir...${NC}"

echo -e "${GREEN}Enter Telegram bot details:${NC}"
read -p "Telegram Bot Token (TELEGRAM_BOT_TOKEN): " TELEGRAM_BOT_TOKEN
if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
  echo -e "${RED}Token cannot be empty!${NC}"
  exit 1
fi
read -p "Admin ID (TELEGRAM_ADMIN_ID): " TELEGRAM_ADMIN_ID
if [ -z "$TELEGRAM_ADMIN_ID" ]; then
  echo -e "${RED}Admin ID cannot be empty!${NC}"
  exit 1
fi

echo -e "${GREEN}Enter system username for docker group:${NC}"
read -p "Username (or Enter for current user): " INPUT_USER
if [ -z "$INPUT_USER" ]; then
  USER_NAME=$(who -u | awk '{print $1}' | head -n 1)
else
  USER_NAME="$INPUT_USER"
fi
if [ -z "$USER_NAME" ] || [ "$USER_NAME" == "root" ]; then
  echo -e "${YELLOW}Valid user not found. Using default (nobody)...${NC}"
  USER_NAME="nobody"
fi
if ! id "$USER_NAME" >/dev/null 2>&1; then
  echo -e "${RED}User $USER_NAME does not exist!${NC}"
  exit 1
fi

echo -e "${GREEN}Updating system and installing tools...${NC}"
apt update && apt upgrade -y
apt install -y curl wget git python3 python3-pip python3-venv
check_error "Failed to install tools"

echo -e "${GREEN}Installing Docker...${NC}"
if ! command -v docker &> /dev/null; then
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
  check_error "Failed to install Docker"
  rm get-docker.sh
else
  echo -e "${YELLOW}Docker already installed${NC}"
fi

echo -e "${GREEN}Adding user $USER_NAME to docker group...${NC}"
if ! getent group docker > /dev/null; then
  echo -e "${YELLOW}Docker group not found. Creating group...${NC}"
  groupadd docker
  check_error "Failed to create docker group"
fi
usermod -aG docker "$USER_NAME"
check_error "Failed to add user $USER_NAME to docker group"

echo -e "${GREEN}Installing Docker Compose...${NC}"
if ! command -v docker-compose &> /dev/null; then
  DOCKER_COMPOSE_VERSION="2.29.7"
  ARCH=$(uname -m)
  case $ARCH in
    x86_64) ARCH="x86_64" ;;
    aarch64) ARCH="aarch64" ;;
    *) echo -e "${RED}Architecture $ARCH not supported!${NC}"; exit 1 ;;
  esac
  curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-${ARCH}" -o /usr/local/bin/docker-compose
  if [ $? -ne 0 ]; then
    echo -e "${YELLOW}Failed to download Docker Compose binary. Trying apt...${NC}"
    apt install -y docker-compose
    check_error "Failed to install Docker Compose via apt"
  else
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    check_error "Failed to install Docker Compose"
  fi
else
  echo -e "${YELLOW}Docker Compose already installed${NC}"
fi
if ! command -v docker-compose &> /dev/null; then
  echo -e "${RED}Docker Compose not installed!${NC}"
  exit 1
fi
echo -e "${GREEN}Docker Compose version: $(docker-compose --version)${NC}"

echo -e "${GREEN}Cloning MarzGozir to /opt/MarzGozir...${NC}"
if [ -d "/opt/MarzGozir" ]; then
  echo -e "${YELLOW}Directory /opt/MarzGozir exists. Removing and re-cloning...${NC}"
  rm -rf /opt/MarzGozir
fi
git clone https://github.com/mahyyar/MarzGozir.git /opt/MarzGozir
check_error "Failed to clone project"
cd /opt/MarzGozir

echo -e "${GREEN}Creating/updating bot_config.py...${NC}"
cat <<EOL > bot_config.py
TOKEN = "$TELEGRAM_BOT_TOKEN"
ADMIN_ID = "$TELEGRAM_ADMIN_ID"
EOL
check_error "Failed to create bot_config.py"

echo -e "${GREEN}Installing Python dependencies...${NC}"
if [ -f "requirements.txt" ]; then
  python3 -m venv venv
  source venv/bin/activate
  pip install --upgrade pip
  pip install -r requirements.txt
  check_error "Failed to install dependencies from requirements.txt"
else
  echo -e "${YELLOW}requirements.txt not found. Installing default dependencies...${NC}"
  python3 -m venv venv
  source venv/bin/activate
  pip install --upgrade pip
  pip install django requests python-telegram-bot
  check_error "Failed to install default dependencies"
fi
deactivate

echo -e "${GREEN}Creating sample .env file...${NC}"
if [ -f ".env.example" ]; then
  cp .env.example .env
  cat <<EOL >> .env
ADMIN_USERNAME=admin
ADMIN_PASSWORD=admin123
DOMAIN=your_domain.com
SSL_ENABLED=false
DATABASE_URL=sqlite:///db.sqlite3
EOL
  echo -e "${YELLOW}.env file created. Edit /opt/MarzGozir/.env to set domain.${NC}"
else
  echo -e "${RED}.env.example not found!${NC}"
  exit 1
fi

echo -e "${GREEN}Running database migrations...${NC}"
source venv/bin/activate
python3 manage.py migrate
check_error "Failed to run migrations"
deactivate

echo -e "${GREEN}Running project with Docker Compose...${NC}"
docker-compose up -d
check_error "Failed to run Docker Compose"

echo -e "${GREEN}Setting up CLI...${NC}"
if [ -f "marzban-cli.py" ]; then
  ln -s /opt/MarzGozir/marzban-cli.py /usr/bin/marzban-cli
  chmod +x /usr/bin/marzban-cli
  source venv/bin/activate
  marzban-cli completion install
  deactivate
  echo -e "${GREEN}CLI installed. Available commands:${NC}"
  echo -e "  - Install bot: marzban-cli bot install"
  echo -e "  - Update bot: marzban-cli bot update"
  echo -e "  - Remove bot: marzban-cli bot remove"
  echo -e "  - Edit token and ID: edit /opt/MarzGozir/bot_config.py"
  echo -e "  - Logout: marzban-cli logout"
else
  echo -e "${YELLOW}marzban-cli.py not found. CLI features may be limited.${NC}"
fi

echo -e "${GREEN}Installation and execution completed!${NC}"
echo -e "${YELLOW}Details:${NC}"
echo -e "- Dashboard: http://your_domain.com:8000/dashboard/"
echo -e "- Config file: /opt/MarzGozir/.env"
echo -e "- Bot config: /opt/MarzGozir/bot_config.py"
echo -e "- Service management:"
echo -e "  Stop: cd /opt/MarzGozir && docker-compose down"
echo -e "  Restart: cd /opt/MarzGozir && docker-compose up -d"
echo -e "- CLI commands: marzban-cli --help"
echo -e "${YELLOW}For security, enable SSL and edit .env.${NC}"
