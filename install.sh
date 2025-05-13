#!/bin/bash

# Colors for output
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

# Variables
DOMAIN="your_domain.com" # Replace with your domain
INSTALL_DIR="/opt/marzgozir"
CONFIG_FILE="$INSTALL_DIR/bot_config.py"
COMPOSE_FILE="$INSTALL_DIR/docker-compose.yml"
REPO_URL="https://github.com/mahyyar/marzgozir.git"

# Function to check and install prerequisites
check_prerequisites() {
    # Check and install git
    if ! command -v git &> /dev/null; then
        echo -e "${YELLOW}Git is not installed. Installing Git...${NC}"
        sudo apt-get update
        sudo apt-get install -y git
    fi
    # Check and install Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Docker is not installed. Installing Docker...${NC}"
        sudo apt-get update
        sudo apt-get install -y docker.io
        sudo systemctl start docker
        sudo systemctl enable docker
    fi
    # Check and install Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${YELLOW}Docker Compose is not installed. Installing Docker Compose...${NC}"
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    fi
}

# Function to get token and admin ID
get_token_and_id() {
    echo -e "${YELLOW}Please enter the Telegram bot token:${NC}"
    read -r BOT_TOKEN
    echo -e "${YELLOW}Please enter the admin ID (numeric only, no brackets):${NC}"
    read -r ADMIN_ID
    if [ -z "$BOT_TOKEN" ] || [ -z "$ADMIN_ID" ]; then
        echo -e "${YELLOW}Error: Bot token and admin ID cannot be empty!${NC}"
        return 1
    fi
    if ! [[ "$ADMIN_ID" =~ ^[0-9]+$ ]]; then
        echo -e "${YELLOW}Error: Admin ID must be numeric only!${NC}"
        return 1
    fi
    echo "$BOT_TOKEN" "$ADMIN_ID"
    return 0
}

# Function to create bot_config.py
create_bot_config() {
    local BOT_TOKEN="$1"
    local ADMIN_ID="$2"
    echo -e "${YELLOW}Creating or updating bot_config.py...${NC}"
    sudo cat <<EOL > $CONFIG_FILE
TOKEN = "$BOT_TOKEN"
ADMIN_ID = [$ADMIN_ID]
DB_PATH = "bot_data.db"
VERSION = "v1.1.1"
CACHE_DURATION = 300
EOL
}

# Function to install dependencies
install_dependencies() {
    if [ -f "$INSTALL_DIR/requirements.txt" ]; then
        echo -e "${YELLOW}Installing Python dependencies...${NC}"
        sudo docker run --rm -v $INSTALL_DIR:/app python:3.9 bash -c "pip install --no-cache-dir -r /app/requirements.txt"
    else
        echo -e "${YELLOW}Warning: requirements.txt not found. Ensure dependencies are included in the project.${NC}"
    fi
}

# Function to install the bot
install_bot() {
    check_prerequisites
    # Remove existing project if it exists
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}Existing project found. Removing...${NC}"
        sudo docker-compose -f $COMPOSE_FILE down -v 2>/dev/null
        sudo rm -rf $INSTALL_DIR
    fi
    # Get token and admin ID
    read -r BOT_TOKEN ADMIN_ID < <(get_token_and_id)
    if [ $? -ne 0 ]; then
        return 1
    fi
    # Clone the repository
    echo -e "${YELLOW}Cloning MarzGozir project...${NC}"
    sudo mkdir -p /opt
    cd /opt
    sudo git clone $REPO_URL marzgozir
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}Error: Cloning repository failed. Check the URL, access permissions, or network connectivity.${NC}"
        echo -e "${YELLOW}Repository URL: $REPO_URL${NC}"
        sudo rm -rf $INSTALL_DIR
        return 1
    fi
    cd $INSTALL_DIR
    # Create bot_config.py
    create_bot_config "$BOT_TOKEN" "$ADMIN_ID"
    # Install dependencies
    install_dependencies
    # Create docker-compose.yml
    echo -e "${YELLOW}Creating docker-compose.yml...${NC}"
    sudo cat <<EOL > $COMPOSE_FILE
version: '3.8'
services:
  marzgozir:
    image: python:3.9
    container_name: marzgozir
    ports:
      - "8000:8000"
    volumes:
      - .:/app
      - /var/lib/marzgozir:/var/lib/marzgozir
    environment:
      - MARZBAN_DOMAIN=$DOMAIN
    working_dir: /app
    command: bash -c "pip install --no-cache-dir -r requirements.txt && python3 main.py"
    restart: unless-stopped
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
    # Start services
    echo -e "${YELLOW}Starting MarzGozir and bot...${NC}"
    sudo docker-compose up -d
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}Error: Starting services failed. Check the logs with 'sudo docker-compose -f $COMPOSE_FILE logs'.${NC}"
        return 1
    fi
    # Display information
    echo -e "${YELLOW}Installation completed successfully!${NC}"
    echo -e "- Dashboard (if enabled): https://$DOMAIN:8000/dashboard/"
    echo -e "${YELLOW}If SSL fails, use http://$DOMAIN:8000/dashboard/ or server IP.${NC}"
    echo -e "${YELLOW}The Telegram bot should be active. Test it with the configured token and ID.${NC}"
}

# Function to update the bot
update_bot() {
    if [ ! -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}Error: Project not installed! Install the bot first.${NC}"
        return 1
    fi
    cd $INSTALL_DIR
    echo -e "${YELLOW}Updating MarzGozir project...${NC}"
    sudo git pull
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}Error: Updating repository failed. Check access or connectivity.${NC}"
        return 1
    fi
    install_dependencies
    echo -e "${YELLOW}Rebuilding and restarting services...${NC}"
    sudo docker-compose up -d --build
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}Error: Rebuilding services failed. Check the logs with 'sudo docker-compose -f $COMPOSE_FILE logs'.${NC}"
        return 1
    fi
    echo -e "${YELLOW}Bot updated successfully!${NC}"
}

# Function to remove the bot
remove_bot() {
    if [ ! -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}Error: Project not installed!${NC}"
        return 1
    fi
    cd $INSTALL_DIR
    echo -e "${YELLOW}Stopping and removing services...${NC}"
    sudo docker-compose down -v
    echo -e "${YELLOW}Removing project directory...${NC}"
    sudo rm -rf $INSTALL_DIR
    echo -e "${YELLOW}Bot and all data removed successfully!${NC}"
}

# Function to edit token and admin ID
edit_token_id() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}Error: bot_config.py not found! Install the bot first.${NC}"
        return 1
    fi
    read -r BOT_TOKEN ADMIN_ID < <(get_token_and_id)
    if [ $? -ne 0 ]; then
        return 1
    fi
    create_bot_config "$BOT_TOKEN" "$ADMIN_ID"
    cd $INSTALL_DIR
    echo -e "${YELLOW}Restarting bot service...${NC}"
    sudo docker-compose restart telegram_bot
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}Error: Restarting bot service failed. Check the logs with 'sudo docker-compose -f $COMPOSE_FILE logs'.${NC}"
        return 1
    fi
    echo -e "${YELLOW}Token and admin ID updated successfully!${NC}"
}

# Main menu
while true; do
    clear
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}      MarzGozir Management Menu      ${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}1. Install Bot${NC}"
    echo -e "${BLUE}2. Update Bot${NC}"
    echo -e "${BLUE}3. Remove Bot${NC}"
    echo -e "${BLUE}4. Edit Token and Admin ID${NC}"
    echo -e "${BLUE}5. Exit${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${YELLOW}Please select an option (1-5):${NC}"
    read -r choice
    case $choice in
        1) install_bot ;;
        2) update_bot ;;
        3) remove_bot ;;
        4) edit_token_id ;;
        5) clear; echo -e "${YELLOW}Exiting script...${NC}"; exit 0 ;;
        *) echo -e "${YELLOW}Invalid option! Please enter a number between 1 and 5.${NC}" ;;
    esac
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read -r
done
