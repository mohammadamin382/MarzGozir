#!/bin/bash

# Color definitions for output
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
NC='\033[0m'

# Directory and file paths
INSTALL_DIR="/opt/marzgozir"
CONFIG_FILE="$INSTALL_DIR/bot_config.py"
COMPOSE_FILE="$INSTALL_DIR/docker-compose.yml"
DATA_DIR="$INSTALL_DIR/data"
REPO_URL="https://github.com/mahyyar/MarzGozir.git"

# Function to check and install prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking system prerequisites...${NC}"
    if ! command -v git &> /dev/null; then
        echo -e "${YELLOW}Git not found. Installing Git...${NC}"
        sudo apt-get update
        sudo apt-get install -y git || { echo -e "${RED}Failed to install Git${NC}"; exit 1; }
    fi
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Docker not found. Installing Docker...${NC}"
        sudo apt-get update
        sudo apt-get install -y docker.io || { echo -e "${RED}Failed to install Docker${NC}"; exit 1; }
        sudo systemctl start docker
        sudo systemctl enable docker
    fi
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${YELLOW}Docker Compose not found. Installing Docker Compose...${NC}"
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose || { echo -e "${RED}Failed to install Docker Compose${NC}"; exit 1; }
        sudo chmod +x /usr/local/bin/docker-compose
    fi
    echo -e "${GREEN}All prerequisites successfully installed${NC}"
}

# Function to collect bot token and admin ID
get_token_and_id() {
    echo -e "${YELLOW}Enter your Telegram bot token:${NC}"
    read -r BOT_TOKEN
    echo -e "${YELLOW}Enter the admin numeric ID (numbers only, no brackets):${NC}"
    read -r ADMIN_ID
    if [ -z "$BOT_TOKEN" ] || [ -z "$ADMIN_ID" ]; then
        echo -e "${RED}Error: Bot token and admin ID cannot be empty!${NC}"
        return 1
    fi
    if ! [[ "$ADMIN_ID" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: Admin ID must contain only numbers!${NC}"
        return 1
    fi
    echo -e "${GREEN}Bot token and admin ID successfully collected${NC}"
    return 0
}

# Function to create or update bot_config.py
create_bot_config() {
    echo -e "${YELLOW}Creating or updating bot_config.py...${NC}"
    mkdir -p "$INSTALL_DIR"
    {
        echo "TOKEN=\"$BOT_TOKEN\""
        echo "ADMIN_IDS=[$ADMIN_ID]"
        echo "DB_PATH=\"data/bot_data.db\""
        echo "VERSION=\"v1.1.1\""
        echo "CACHE_DURATION=300"
    } > "$CONFIG_FILE"
    chmod 644 "$CONFIG_FILE"
    echo -e "${GREEN}Configuration file bot_config.py created successfully${NC}"
}

# Function to set up database directory and permissions
setup_data_directory() {
    echo -e "${YELLOW}Setting up database directory and permissions...${NC}"
    mkdir -p "$DATA_DIR"
    chmod 777 "$DATA_DIR"
    rm -f "$INSTALL_DIR/bot_data.db"
    echo -e "${GREEN}Database directory configured successfully${NC}"
}

# Function to verify required files
check_required_files() {
    echo -e "${YELLOW}Verifying required files...${NC}"
    for file in Dockerfile docker-compose.yml requirements.txt main.py bot/handlers.py; do
        if [ ! -f "$INSTALL_DIR/$file" ]; then
            echo -e "${RED}Error: File $file not found!${NC}"
            return 1
        fi
    done
    echo -e "${GREEN}All required files are present${NC}"
    return 0
}

# Function to install the bot
install_bot() {
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}Existing directory detected. Removing old files...${NC}"
        sudo docker-compose -f "$COMPOSE_FILE" down 2>/dev/null || true
        sudo rm -rf "$INSTALL_DIR"
    fi
    check_prerequisites
    echo -e "${YELLOW}Cloning repository from $REPO_URL...${NC}"
    git clone "$REPO_URL" "$INSTALL_DIR" || { echo -e "${RED}Failed to clone repository${NC}"; exit 1; }
    cd "$INSTALL_DIR" || exit 1
    check_required_files || { echo -e "${RED}Required files are missing${NC}"; exit 1; }
    get_token_and_id || { echo -e "${RED}Failed to collect token and ID${NC}"; exit 1; }
    create_bot_config
    setup_data_directory
    echo -e "${YELLOW}Building and starting bot with Docker Compose...${NC}"
    sudo docker-compose build --no-cache || { echo -e "${RED}Failed to build Docker image${NC}"; exit 1; }
    sudo docker-compose up -d || { echo -e "${RED}Failed to start Docker Compose${NC}"; sudo docker-compose logs; exit 1; }
    echo -e "${GREEN}Bot installed and running successfully!${NC}"
}

# Function to uninstall the bot
uninstall_bot() {
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}Stopping and removing bot...${NC}"
        cd "$INSTALL_DIR" || exit 1
        sudo docker-compose -f "$COMPOSE_FILE" down 2>/dev/null || true
        sudo rm -rf "$INSTALL_DIR"
        echo -e "${GREEN}Bot uninstalled successfully${NC}"
    else
        echo -e "${RED}Bot is not installed!${NC}"
    fi
}

# Function to restart the bot
restart_bot() {
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}Restarting bot...${NC}"
        cd "$INSTALL_DIR" || exit 1
        sudo docker-compose -f "$COMPOSE_FILE" restart || { echo -e "${RED}Failed to restart bot${NC}"; exit 1; }
        echo -e "${GREEN}Bot restarted successfully${NC}"
    else
        echo -e "${RED}Bot is not installed!${NC}"
    fi
}

# Function to reset token and ID
reset_token_and_id() {
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}Resetting bot token and admin ID...${NC}"
        get_token_and_id || { echo -e "${RED}Failed to collect token and ID${NC}"; exit 1; }
        create_bot_config
        restart_bot
    else
        echo -e "${RED}Configuration file not found! Please install the bot first.${NC}"
    fi
}

# Function to clear the project
clear_project() {
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}Clearing project...${NC}"
        cd "$INSTALL_DIR" || exit 1
        sudo docker-compose -f "$COMPOSE_FILE" down 2>/dev/null || true
        sudo rm -rf "$INSTALL_DIR"
        echo -e "${GREEN}Project cleared successfully${NC}"
    else
        echo -e "${RED}No project exists to clear!${NC}"
    fi
}

# Function to display the menu
show_menu() {
    clear
    echo -e "${YELLOW}==== Bot Management Menu ====${NC}"
    echo "1) Install Bot"
    echo "2) Uninstall Bot"
    echo "3) Restart Bot"
    echo "4) Reset Token and Numeric ID (edit bot_config.py)"
    echo "5) Clear Project"
    echo "6) Exit"
    echo -e "${YELLOW}Please select an option (1-6):${NC}"
}

# Main menu loop
while true; do
    show_menu
    read -r choice
    case $choice in
        1) install_bot ;;
        2) uninstall_bot ;;
        3) restart_bot ;;
        4) reset_token_and_id ;;
        5) clear_project ;;
        6) echo -e "${GREEN}Exiting program...${NC}"; exit 0 ;;
        *) echo -e "${RED}Invalid option! Please select a number between 1 and 6.${NC}" ;;
    esac
    echo -e "${YELLOW}Press any key to return to the menu...${NC}"
    read -n 1
done
