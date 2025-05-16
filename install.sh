#!/bin/bash

YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
NC='\033[0m'

INSTALL_DIR="/opt/marzgozir"
CONFIG_FILE="$INSTALL_DIR/bot_config.py"
COMPOSE_FILE="$INSTALL_DIR/docker-compose.yml"
DATA_DIR="$INSTALL_DIR/data"
DB_FILE="$DATA_DIR/bot_data.db"
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
        read -r TOKEN
        echo -e "${YELLOW}Enter the admin numeric ID (numbers only, no brackets):${NC}"
        read -r ADMIN_ID
        if [ -z "$TOKEN" ] || [ -z "$ADMIN_ID" ]; then
            echo -e "${RED}Error: Bot token and admin ID cannot be empty!${NC}"
            continue
        fi
        if ! [[ "$TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
            echo -e "${RED}Error: Invalid bot token format! It should look like '123456789:ABCDEF1234567890abcdef1234567890'${NC}"
            continue
        fi
        if ! [[ "$ADMIN_ID" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}Error: Admin ID must contain only numbers!${NC}"
            continue
        fi
        if ! validate_token "$TOKEN"; then
            echo -e "${RED}Please try again with a valid token${NC}"
            continue
        fi
        echo -e "${GREEN}Bot token and admin ID successfully collected${NC}"
        echo -e "${YELLOW}Collected TOKEN: $TOKEN${NC}"
        echo -e "${YELLOW}Collected ADMIN_ID: $ADMIN_ID${NC}"
        export TOKEN ADMIN_ID
        return 0
    done
}

extract_token_and_id() {
    echo -e "${YELLOW}Extracting token and admin ID from bot_config.py...${NC}"
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}Current bot_config.py content:${NC}"
        cat "$CONFIG_FILE"
        TOKEN=$(grep -E "^TOKEN\s*=" "$CONFIG_FILE" | sed -E "s/TOKEN\s*=\s*['\"]?([^'\"]+)['\"]?/\1/" | tr -d ' ')
        ADMIN_ID=$(grep -E "^ADMIN_IDS\s*=" "$CONFIG_FILE" | sed -E "s/ADMIN_IDS\s*=\s*\[(.*)\]/\1/" | tr -d ' ')
        if [ -n "$TOKEN" ] && [ -n "$ADMIN_ID" ] && [[ "$TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]] && [[ "$ADMIN_ID" =~ ^[0-9]+$ ]]; then
            echo -e "${YELLOW}Extracted TOKEN: $TOKEN${NC}"
            echo -e "${YELLOW}Extracted ADMIN_ID: $ADMIN_ID${NC}"
            if validate_token "$TOKEN"; then
                echo -e "${GREEN}Valid token and admin ID extracted${NC}"
                export TOKEN ADMIN_ID
                return 0
            fi
        fi
        echo -e "${RED}Invalid or missing token/admin ID in bot_config.py${NC}"
    else
        echo -e "${RED}bot_config.py not found${NC}"
    fi
    get_token_and_id
}

edit_bot_config() {
    echo -e "${YELLOW}Editing bot_config.py...${NC}"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}bot_config.py not found in repository, creating default...${NC}"
        cat > "$CONFIG_FILE" << EOF
TOKEN = "SET_YOUR_TOKEN"
ADMIN_IDS = [123456789]
DB_PATH = "bot_data.db"
CACHE_DURATION = 30
VERSION = "V1.1.3"
EOF
    fi
    # Fix malformed TOKEN line
    sed -i 's|^TOKEN\s*=\s*SET_YOUR_TOKEN.*|TOKEN = "SET_YOUR_TOKEN"|' "$CONFIG_FILE"
    echo -e "${YELLOW}Before edit - bot_config.py content:${NC}"
    cat "$CONFIG_FILE"
    echo -e "${YELLOW}Using TOKEN: $TOKEN${NC}"
    echo -e "${YELLOW}Using ADMIN_ID: $ADMIN_ID${NC}"
    sed -i "s|^TOKEN\s*=\s*['\"].*['\"]|TOKEN = \"$TOKEN\"|" "$CONFIG_FILE"
    sed -i "s|^ADMIN_IDS\s*=\s*\[.*\]|ADMIN_IDS = [$ADMIN_ID]|" "$CONFIG_FILE"
    chmod 644 "$CONFIG_FILE"
    echo -e "${YELLOW}After edit - bot_config.py content:${NC}"
    cat "$CONFIG_FILE"
    # Verify the changes
    if grep -q "TOKEN = \"$TOKEN\"" "$CONFIG_FILE" && grep -q "ADMIN_IDS = \[$ADMIN_ID\]" "$CONFIG_FILE"; then
        echo -e "${GREEN}bot_config.py updated successfully${NC}"
    else
        echo -e "${RED}Error: Failed to update bot_config.py${NC}"
        echo -e "${YELLOW}Expected TOKEN: $TOKEN${NC}"
        echo -e "${YELLOW}Expected ADMIN_ID: $ADMIN_ID${NC}"
        exit 1
    fi
}

setup_data_directory() {
    echo -e "${YELLOW}Setting up database directory and permissions...${NC}"
>U    mkdir -p "$DATA_DIR"
    chmod 777 "$DATA_DIR"
    rm -f "$DB_FILE"
    echo -e "${GREEN}Database directory configured successfully${NC}"
}

check_required_files() {
    echo -e "${YELLOW}Verifying required files...${NC}"
    for file in Dockerfile docker-compose.yml requirements.txt main.py bot/handlers.py bot/menus.py bot/states.py database/db.py utils/message_utils.py utils/activity_logger.py; do
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
    if [ -f "$COMPOSE_FILE" ]; then
        sudo docker-compose -f "$COMPOSE_FILE" down --volumes --rmi all 2>/dev/null || true
    fi
    sudo docker images -q -f "reference=$PROJECT_NAME" | sort -u | xargs -r sudo docker rmi 2>/dev/null || true
    sudo docker ps -a -q -f "name=$PROJECT_NAME" | xargs -r sudo docker rm 2>/dev/null || true
    echo -e "${GREEN}Docker cleanup completed${NC}"
}

check_container_status() {
    echo -e "${YELLOW}Checking container status...${NC}"
    sleep 5
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
    echo -e "${YELLOW}Starting bot installation...${NC}"
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}Existing directory detected. Removing old installation...${NC}"
        cd /tmp || { echo -e "${RED}Failed to change to /tmp${NC}"; exit 1; }
        cleanup_docker
        sudo rm -rf "$INSTALL_DIR" || { echo -e "${RED}Failed to remove $INSTALL_DIR${NC}"; exit 1; }
        if [ -d "$INSTALL_DIR" ]; then
            echo -e "${RED}Error: Directory $INSTALL_DIR still exists after removal attempt${NC}"
            exit 1
        fi
    fi
    check_prerequisites
    echo -e "${YELLOW}Cloning repository from $REPO_URL into $INSTALL_DIR...${NC}"
    cd /tmp || { echo -e "${RED}Failed to change to /tmp${NC}"; exit 1; }
    git clone "$REPO_URL" "$INSTALL_DIR" 2>&1 || { echo -e "${RED}Failed to clone repository${NC}"; exit 1; }
    cd "$INSTALL_DIR" || { echo -e "${RED}Failed to change to $INSTALL_DIR${NC}"; exit 1; }
    check_required_files || { echo -e "${RED}Required files are missing${NC}"; exit 1; }
    get_token_and_id || { echo -e "${RED}Failed to collect token and ID${NC}"; exit 1; }
    edit_bot_config
    setup_data_directory
    echo -e "${YELLOW}Building and starting bot with Docker Compose...${NC}"
    sudo docker-compose build --no-cache || { echo -e "${RED}Failed to build Docker image${NC}"; exit 1; }
    sudo docker-compose up -d || { echo -e "${RED}Failed to start Docker Compose${NC}"; sudo docker-compose logs; exit 1; }
    check_container_status || exit 1
    echo -e "${GREEN}Bot installed and running successfully!${NC}"
}

uninstall_bot() {
    echo -e "${YELLOW}Uninstalling bot...${NC}"
    if [ -d "$INSTALL_DIR" ]; then
        cd "$INSTALL_DIR" || exit 1
        cleanup_docker
        cd /tmp || { echo -e "${RED}Failed to change to /tmp${NC}"; exit 1; }
        sudo rm -rf "$INSTALL_DIR" || { echo -e "${RED}Failed to remove $INSTALL_DIR${NC}"; exit 1; }
        echo -e "${GREEN}Bot uninstalled successfully${NC}"
    else
        echo -e "${RED}Bot is not installed!${NC}"
    fi
}

update_bot() {
    echo -e "${YELLOW}Updating bot...${NC}"
    if [ -d "$INSTALL_DIR" ]; then
        cd "$INSTALL_DIR" || exit 1
        # Backup database
        if [ -f "$DB_FILE" ]; then
            cp "$DB_FILE" "/tmp/bot_data.db.bak" || { echo -e "${RED}Failed to backup database${NC}"; exit 1; }
        fi
        # Extract token and admin ID
        extract_token_and_id
        # Clean up Docker and remove project directory
        cleanup_docker
        cd /tmp || { echo -e "${RED}Failed to change to /tmp${NC}"; exit 1; }
        sudo rm -rf "$INSTALL_DIR" || { echo -e "${RED}Failed to remove $INSTALL_DIR${NC}"; exit 1; }
        if [ -d "$INSTALL_DIR" ]; then
            echo -e "${RED}Error: Directory $INSTALL_DIR still exists after removal attempt${NC}"
            exit 1
        fi
        # Re-clone repository
        echo -e "${YELLOW}Cloning repository from $REPO_URL into $INSTALL_DIR...${NC}"
        git clone "$REPO_URL" "$INSTALL_DIR" 2>&1 || { echo -e "${RED}Failed to clone repository${NC}"; exit 1; }
        cd "$INSTALL_DIR" || { echo -e "${RED}Failed to change to $INSTALL_DIR${NC}"; exit 1; }
        check_required_files || { echo -e "${RED}Required files are missing${NC}"; exit 1; }
        # Restore database
        if [ -f "/tmp/bot_data.db.bak" ]; then
            mkdir -p "$DATA_DIR"
            mv "/tmp/bot_data.db.bak" "$DB_FILE" || { echo -e "${RED}Failed to restore database${NC}"; exit 1; }
            chmod 777 "$DATA_DIR"
        fi
        # Edit config with stored token and admin ID
        edit_bot_config
        echo -e "${YELLOW}Building and starting bot with Docker Compose...${NC}"
        sudo docker-compose build --no-cache || { echo -e "${RED}Failed to build Docker image${NC}"; exit 1; }
        sudo docker-compose up -d || { echo -e "${RED}Failed to start Docker Compose${NC}"; sudo docker-compose logs; exit 1; }
        check_container_status || exit 1
        echo -e "${GREEN}Bot updated and running successfully!${NC}"
    else
        echo -e "${RED}Bot is not installed!${NC}"
    fi
}

restart_bot() {
    echo -e "${YELLOW}Restarting bot...${NC}"
    if [ -d "$INSTALL_DIR" ]; then
        cd "$INSTALL_DIR" || exit 1
        sudo docker-compose restart || { echo -e "${RED}Failed to restart bot${NC}"; exit 1; }
        check_container_status || exit 1
        echo -e "${GREEN}Bot restarted successfully${NC}"
    else
        echo -e "${RED}Bot is not installed!${NC}"
    fi
}

reset_token_and_id() {
    echo -e "${YELLOW}Resetting bot token and admin ID...${NC}"
    if [ -d "$INSTALL_DIR" ]; then
        cd "$INSTALL_DIR" || exit 1
        get_token_and_id || { echo -e "${RED}Failed to collect token and ID${NC}"; exit 1; }
        edit_bot_config
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
