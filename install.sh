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
    if ! command -v git &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y git || { echo -e "${RED}Failed to install Git${NC}"; exit 1; }
    fi
    if ! command -v docker &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y docker.io || { echo -e "${RED}Failed to install Docker${NC}"; exit 1; }
        sudo systemctl start docker
        sudo systemctl enable docker
    fi
    if ! command -v docker-compose &> /dev/null; then
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose || { echo -e "${RED}Failed to install Docker Compose${NC}"; exit 1; }
        sudo chmod +x /usr/local/bin/docker-compose
    fi
    if ! command -v curl &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y curl || { echo -e "${RED}Failed to install Curl${NC}"; exit 1; }
    fi
}

validate_token() {
    local token=$1
    response=$(curl -s "https://api.telegram.org/bot${token}/getMe")
    if [[ "$response" =~ \"ok\":true ]]; then
        return 0
    else
        echo -e "${RED}Invalid bot token${NC}"
        return 1
    fi
}

get_token_and_id() {
    while true; do
        echo -e "${YELLOW}Enter Telegram bot token:${NC}"
        read -r TOKEN
        echo -e "${YELLOW}Enter admin numeric ID:${NC}"
        read -r ADMIN_ID
        if [ -z "$TOKEN" ] || [ -z "$ADMIN_ID" ]; then
            echo -e "${RED}Token and ID cannot be empty${NC}"
            continue
        fi
        if ! [[ "$TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
            echo -e "${RED}Invalid token format${NC}"
            continue
        fi
        if ! [[ "$ADMIN_ID" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}Admin ID must be numbers${NC}"
            continue
        fi
        if ! validate_token "$TOKEN"; then
            continue
        fi
        export TOKEN ADMIN_ID
        return 0
    done
}

extract_token_and_id() {
    if [ -f "$CONFIG_FILE" ]; then
        TOKEN=$(grep -E "^TOKEN=" "$CONFIG_FILE" | cut -d'"' -f2)
        ADMIN_ID=$(grep -E "^ADMIN_IDS=" "$CONFIG_FILE" | cut -d'[' -f2 | cut -d']' -f1)
        if [ -n "$TOKEN" ] && [ -n "$ADMIN_ID" ] && [[ "$TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]] && [[ "$ADMIN_ID" =~ ^[0-9]+$ ]]; then
            if validate_token "$TOKEN"; then
                export TOKEN ADMIN_ID
                return 0
            fi
        fi
        echo -e "${RED}Invalid token/ID in bot_config.py${NC}"
    fi
    get_token_and_id
}

edit_bot_config() {
    mkdir -p "$INSTALL_DIR"
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << EOF
TOKEN="SET_YOUR_TOKEN"
ADMIN_IDS=[123456789]
DB_PATH="bot_data.db"
CACHE_DURATION=300
EOF
    fi
    sed -i "s/TOKEN=.*/TOKEN=\"$TOKEN\"/" "$CONFIG_FILE"
    sed -i "s/ADMIN_IDS=.*/ADMIN_IDS=[$ADMIN_ID]/" "$CONFIG_FILE"
    chmod 644 "$CONFIG_FILE"
}

setup_data_directory() {
    mkdir -p "$DATA_DIR"
    chmod 777 "$DATA_DIR"
}

check_required_files() {
    for file in Dockerfile docker-compose.yml requirements.txt main.py bot/handlers.py bot/menus.py bot/states.py database/db.py utils/message_utils.py utils/activity_logger.py; do
        if [ ! -f "$INSTALL_DIR/$file" ]; then
            echo -e "${RED}File $file missing${NC}"
            return 1
        fi
    done
    return 0
}

validate_repo() {
    if ! curl -s --head "$REPO_URL" | grep -q "200 OK"; then
        echo -e "${RED}Repository $REPO_URL is not accessible. Check if it exists or is private.${NC}"
        echo -e "${YELLOW}Enter a valid repository URL (or press Enter to retry default):${NC}"
        read -r NEW_URL
        if [ -n "$NEW_URL" ]; then
            REPO_URL="$NEW_URL"
        fi
        if ! curl -s --head "$REPO_URL" | grep -q "200 OK"; then
            echo -e "${RED}Repository still inaccessible${NC}"
            exit 1
        fi
    fi
}

cleanup_docker() {
    sudo docker-compose -f "$COMPOSE_FILE" down 2>/dev/null || true
    sudo docker images -q -f "reference=$PROJECT_NAME" | sort -u | xargs -r sudo docker rmi 2>/dev/null || true
    sudo docker ps -a -q -f "name=$PROJECT_NAME" | xargs -r sudo docker rm 2>/dev/null || true
}

check_container_status() {
    sleep 5
    if [ -n "$(sudo docker ps -q -f "name=$PROJECT_NAME")" ]; then
        return 0
    else
        echo -e "${RED}Container failed to start${NC}"
        sudo docker-compose logs
        return 1
    fi
}

install_bot() {
    if [ -d "$INSTALL_DIR" ]; then
        cd "$INSTALL_DIR" 2>/dev/null && cleanup_docker || true
        sudo rm -rf "$INSTALL_DIR"
    fi
    check_prerequisites
    validate_repo
    mkdir -p "$INSTALL_DIR" || { echo -e "${RED}Failed to create $INSTALL_DIR${NC}"; exit 1; }
    cd /tmp || { echo -e "${RED}Failed to change to /tmp${NC}"; exit 1; }
    sudo git clone "$REPO_URL" "$INSTALL_DIR" || { echo -e "${RED}Failed to clone repository${NC}"; exit 1; }
    cd "$INSTALL_DIR" || { echo -e "${RED}Failed to change to $INSTALL_DIR${NC}"; exit 1; }
    check_required_files || { echo -e "${RED}Required files missing${NC}"; exit 1; }
    get_token_and_id || { echo -e "${RED}Failed to collect token/ID${NC}"; exit 1; }
    edit_bot_config
    setup_data_directory
    sudo docker-compose build --no-cache || { echo -e "${RED}Failed to build Docker image${NC}"; exit 1; }
    sudo docker-compose up -d || { echo -e "${RED}Failed to start Docker Compose${NC}"; sudo docker-compose logs; exit 1; }
    check_container_status || exit 1
    echo -e "${GREEN}Bot installed${NC}"
}

uninstall_bot() {
    if [ -d "$INSTALL_DIR" ]; then
        cd "$INSTALL_DIR" || exit 1
        cleanup_docker
        sudo rm -rf "$INSTALL_DIR"
        echo -e "${GREEN}Bot uninstalled${NC}"
    else
        echo -e "${RED}Bot not installed${NC}"
    fi
}

update_bot() {
    if [ -d "$INSTALL_DIR" ]; then
        cd "$INSTALL_DIR" || exit 1
        if [ -f "$DB_FILE" ]; then
            cp "$DB_FILE" "/tmp/bot_data.db.bak"
        fi
        if [ -f "$CONFIG_FILE" ]; then
            cp "$CONFIG_FILE" "/tmp/bot_config.py.bak"
        fi
        cleanup_docker
        git reset --hard || { echo -e "${RED}Failed to reset changes${NC}"; exit 1; }
        git clean -fd || { echo -e "${RED}Failed to clean files${NC}"; exit 1; }
        validate_repo
        git pull || { echo -e "${RED}Failed to update repository${NC}"; exit 1; }
        if [ -f "/tmp/bot_config.py.bak" ]; then
            mv "/tmp/bot_config.py.bak" "$CONFIG_FILE"
        fi
        if [ -f "/tmp/bot_data.db.bak" ]; then
            mkdir -p "$DATA_DIR"
            mv "/tmp/bot_data.db.bak" "$DB_FILE"
            chmod 777 "$DB_FILE"
        fi
        check_required_files || { echo -e "${RED}Required files missing${NC}"; exit 1; }
        sudo docker-compose build --no-cache || { echo -e "${RED}Failed to build Docker image${NC}"; exit 1; }
        sudo docker-compose up -d || { echo -e "${RED}Failed to start Docker Compose${NC}"; sudo docker-compose logs; exit 1; }
        check_container_status || exit 1
        echo -e "${GREEN}Bot updated${NC}"
    else
        echo -e "${RED}Bot not installed${NC}"
    fi
}

restart_bot() {
    if [ -d "$INSTALL_DIR" ]; then
        cd "$INSTALL_DIR" || exit 1
        sudo docker-compose restart || { echo -e "${RED}Failed to restart bot${NC}"; exit 1; }
        check_container_status || exit 1
        echo -e "${GREEN}Bot restarted${NC}"
    else
        echo -e "${RED}Bot not installed${NC}"
    fi
}

reset_token_and_id() {
    if [ -d "$INSTALL_DIR" ]; then
        cd "$INSTALL_DIR" || exit 1
        get_token_and_id || { echo -e "${RED}Failed to collect token/ID${NC}"; exit 1; }
        edit_bot_config
        restart_bot
    else
        echo -e "${RED}Bot not installed${NC}"
    fi
}

show_menu() {
    clear
    echo -e "${YELLOW}===== MarzGozir Bot Menu =====${NC}"
    echo "1) Install Bot"
    echo "2) Update Bot"
    echo "3) Uninstall Bot"
    echo "4) Change Token/ID"
    echo "5) Restart Bot"
    echo "6) Exit"
    echo -e "${YELLOW}Select (1-6):${NC}"
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
        6) echo -e "${GREEN}Exiting...${NC}"; exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}" ;;
    esac
    echo -e "${YELLOW}Press any key...${NC}"
    read -n 1
done
