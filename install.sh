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
PROJECT_NAME="marzgozir"

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
    if ! command -v curl &> /dev/null; then
        echo -e "${YELLOW}Curl not found. Installing Curl...${NC}"
        sudo apt-get update
        sudo apt-get install -y curl || { echo -e "${RED}Failed to install Curl${NC}"; exit 1; }
    fi
    echo -e "${GREEN}All prerequisites successfully installed${NC}"
}

validate_token() {
    local token=$1
    echo -e "${YELLOW}Validating Telegram bot token...${NC}"
    response=$(curl -s "https://api.telegram.org/bot${token}/getMe")
    if [[ "$response" =~ \"ok\":true ]]; then
        echo -e "${GREEN}Bot token is valid${NC}"
        return 0
    else
        echo -e "${RED}Error: Invalid bot token! Response: $response${NC}"
        return 1
    fi
}

get_token_and_id() {
    while true; do
        echo -e "${YELLOW}Enter your Telegram bot token:${NC}"
        read -r BOT_TOKEN
        echo -e "${YELLOW}Enter the admin numeric ID (numbers only, no brackets):${NC}"
        read -r ADMIN_ID
        if [ -z "$BOT_TOKEN" ] || [ -z "$ADMIN_ID" ]; then
            echo -e "${RED}Error: Bot token and admin ID cannot be empty!${NC}"
            continue
        fi
        if ! [[ "$BOT_TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
            echo -e "${RED}Error: Invalid bot token format! It should look like '123456789:ABCDEF1234567890abcdef1234567890'${NC}"
            continue
        fi
        if ! [[ "$ADMIN_ID" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}Error: Admin ID must contain only numbers!${NC}"
            continue
        fi
        if ! validate_token "$BOT_TOKEN"; then
            echo -e "${RED}Please try again with a valid token${NC}"
            continue
        fi
        echo -e "${GREEN}Bot token and admin ID successfully collected${NC}"
        export BOT_TOKEN ADMIN_ID
        return 0
    done
}

create_bot_config() {
    echo -e "${YELLOW}Creating or updating bot_config.py...${NC}"
    mkdir -p "$INSTALL_DIR"
    cat > "$CONFIG_FILE" << EOF
BOT_TOKEN="$BOT_TOKEN"
ADMIN_IDS=[$ADMIN_ID]
VERSION="v0.1.0"
EOF
    chmod 644 "$CONFIG_FILE"
    echo -e "${GREEN}Configuration file bot_config.py created successfully${NC}"
}

setup_data_directory() {
    echo -e "${YELLOW}Setting up database directory and permissions...${NC}"
    mkdir -p "$DATA_DIR"
    chmod 777 "$DATA_DIR"
    rm -f "$DATA_DIR/bot_data.db"
    echo -e "${GREEN}Database directory configured successfully${NC}"
}

check_required_files() {
    echo -e "${YELLOW}Verifying required files...${NC}"
    for file in Dockerfile docker-compose.yml requirements.txt main.py bot/handlers.py bot/menus.py bot/states.py database/db.py utils/activity_logger.py; do
        if [ ! -f "$INSTALL_DIR/$file" ]; then
            echo -e "${RED}Error: File $file not found!${NC}"
            return 1
        fi
    done
    echo -e "${GREEN}All required files are present${NC}"
    return 0
}

cleanup_docker() {
    echo -e "${YELLOW}Cleaning up existing Docker containers, images, and volumes...${NC}"
    # Stop and remove containers
    sudo docker-compose -f "$COMPOSE_FILE" down --volumes --rmi all 2>/dev/null || true
    # Remove any dangling images
    sudo docker images -q -f "reference=$PROJECT_NAME" | sort -u | xargs -r sudo docker rmi 2>/dev/null || true
    # Remove any orphaned containers
    sudo docker ps -a -q -f "name=$PROJECT_NAME" | xargs -r sudo docker rm 2>/dev/null || true
    echo -e "${GREEN}Docker cleanup completed${NC}"
}

check_container_status() {
    echo -e "${YELLOW}Checking container status...${NC}"
    sleep 5  # Wait for container to start
    container_status=$(sudo docker ps -q -f "name=$PROJECT_NAME")
    if [ -n "$container_status" ]; then
        echo -e "${GREEN}Container is running successfully${NC}"
        return 0
    else
        echo -e "${RED}Error: Container failed to start${NC}"
        sudo docker-compose logs
        return 1
    fi
}

install_bot() {
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}Existing directory detected. Removing old installation...${NC}"
        cleanup_docker
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
    check_container_status || exit 1
    echo -e "${GREEN}Bot installed and running successfully!${NC}"
}

uninstall_bot() {
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}Stopping and removing bot...${NC}"
        cd "$INSTALL_DIR" || exit 1
        cleanup_docker
        sudo rm -rf "$INSTALL_DIR"
        echo -e "${GREEN}Bot uninstalled successfully${NC}"
    else
        echo -e "${RED}Bot is not installed!${NC}"
    fi
}

update_bot() {
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}Updating bot...${NC}"
        cd "$INSTALL_DIR" || exit 1
        cleanup_docker
        git pull || { echo -e "${RED}Failed to update repository${NC}"; exit 1; }
        check_required_files || { echo -e "${RED}Required files are missing${NC}"; exit 1; }
        echo -e "${YELLOW}Building and starting bot with Docker Compose...${NC}"
        sudo docker-compose build --no-cache || { echo -e "${RED}Failed to build Docker image${NC}"; exit 1; }
        sudo docker-compose up -d || { echo -e "${RED}Failed to start Docker Compose${NC}"; sudo docker-compose logs; exit 1; }
        check_container_status || exit 1
        echo -e "${GREEN}Bot updated and running successfully${NC}"
    else
        echo -e "${RED}Bot is not installed!${NC}"
    fi
}

restart_bot() {
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}Restarting bot...${NC}"
        cd "$INSTALL_DIR" || exit 1
        sudo docker-compose restart || { echo -e "${RED}Failed to restart bot${NC}"; exit 1; }
        check_container_status || exit 1
        echo -e "${GREEN}Bot restarted successfully${NC}"
    else
        echo -e "${RED}Bot is not installed!${NC}"
    fi
}

reset_token_and_id() {
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}Resetting bot token and admin ID...${NC}"
        cd "$INSTALL_DIR" || exit 1
        get_token_and_id || { echo -e "${RED}Failed to collect token and ID${NC}"; exit 1; }
        create_bot_config
        restart_bot
    else
        echo -e "${RED}Bot is not installed!${NC}"
    fi
}

show_menu() {
    clear
    echo -e "${YELLOW}===== MarzGozir Bot Management Menu =====${NC}"
    echo "1) Install Bot"
    echo "2) Update Bot"
    echo "3) Uninstall Bot"
    echo "4) Change Bot Token and Admin ID"
    echo "5) Restart Bot"
    echo "6) Exit"
    echo -e "${YELLOW}Please select an option (1-6):${NC}"
}

while true; do
    show_menu
    read -r choice
    case $choice in
        1) install_bot ;;
        2) update_bot ;;
        3) uninstall_bot ;;
        4) reset_token_and_id ;;
        5) restart_bot ;;
        6) echo -e "${GREEN}Exiting program...${NC}"; exit 0 ;;
        *) echo -e "${RED}Invalid option! Please select a number between 1 and 6.${NC}" ;;
    esac
    echo -e "${YELLOW}Press any key to return to the menu...${NC}"
    read -n 1
done
