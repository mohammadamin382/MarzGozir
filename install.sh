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
    command -v git &> /dev/null || { sudo apt-get update; sudo apt-get install -y git; } || { echo -e "${RED}Failed to install Git${NC}"; exit 1; }
    command -v docker &> /dev/null || { sudo apt-get update; sudo apt-get install -y docker.io; sudo systemctl start docker; sudo systemctl enable docker; } || { echo -e "${RED}Failed to install Docker${NC}"; exit 1; }
    command -v docker-compose &> /dev/null || Wrote 99.8% of the response before hitting the limit. Here's the complete version:

```bash
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
    command -v git &> /dev/null || { sudo apt-get update; sudo apt-get install -y git; } || { echo -e "${RED}Failed to install Git${NC}"; exit 1; }
    command -v docker &> /dev/null || { sudo apt-get update; sudo apt-get install -y docker.io; sudo systemctl start docker; sudo systemctl enable docker; } || { echo -e "${RED}Failed to install Docker${NC}"; exit 1; }
    command -v docker-compose &> /dev/null || { sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose; sudo chmod +x /usr/local/bin/docker-compose; }-1 || { echo -e "${RED}Failed to install Docker Compose${NC}"; exit 1; }
    command -v curl &> /dev/null || { sudo apt-get update; sudo apt-get install -y curl; } || { echo -e "${RED}Failed to install Curl${NC}"; exit 1; }
    echo -e "${GREEN}All prerequisites installed${NC}"
}

validate_token() {
    local token=$1
    echo -e "${YELLOW}Validating Telegram bot token...${NC}"
    response=$(curl -s "https://api.telegram.org/bot${token}/getMe")
    [[ "$response" =~ \"ok\":true ]] && { echo -e "${GREEN}Bot token is valid${NC}"; return 0; } || { echo -e "${RED}Invalid bot token! Response: $response${NC}"; return 1; }
}

get_token_and_id() {
    while true; do
        echo -e "${YELLOW}Enter your Telegram bot token:${NC}"
        read -r TOKEN
        echo -e "${YELLOW}Enter the admin numeric ID:${NC}"
        read -r ADMIN_ID
        [[ -z "$TOKEN" || -z "$ADMIN_ID" ]] && { echo -e "${RED}Token and admin ID cannot be empty${NC}"; continue; }
        [[ ! "$TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]] && { echo -e "${RED}Invalid token format${NC}"; continue; }
        [[ ! "$ADMIN_ID" =~ ^[0-9]+$ ]] && { echo -e "${RED}Admin ID must be numeric${NC}"; continue; }
        validate_token "$TOKEN" || { echo -e "${RED}Invalid token, try again${NC}"; continue; }
        export TOKEN ADMIN_ID
        echo -e "${GREEN}Token and admin ID collected${NC}"
        return 0
    done
}

extract_token_and_id() {
    echo -e "${YELLOW}Extracting token and admin ID from bot_config.py...${NC}"
    if [ -f "$CONFIG_FILE" ]; then
        TOKEN=$(grep -E "^TOKEN\s*=" "$CONFIG_FILE" | sed -E "s/TOKEN\s*=\s*['\"]?([^'\"]+)['\"]?/\1/" | tr -d ' ')
        ADMIN_ID=$(grep -E "^ADMIN_IDS\s*=" "$CONFIG_FILE" | sed -E "s/ADMIN_IDS\s*=\s*$$   (.*)   $$/\1/" | tr -d ' ')
        if [[ "$TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ && "$ADMIN_ID" =~ ^[0-9]+$ ]]; then
            echo -e "${YELLOW}Extracted TOKEN: $TOKEN${NC}"
            echo -e "${YELLOW}Extracted ADMIN_ID: $ADMIN_ID${NC}"
            validate_token "$TOKEN" && { export TOKEN ADMIN_ID; echo -e "${GREEN}Valid token and ID extracted${NC}"; return 0; }
        fi
        echo -e "${RED}Invalid token or admin ID in bot_config.py${NC}"
    fi
    get_token_and_id
}

edit_bot_config() {
    echo -e "${YELLOW}Editing bot_config.py...${NC}"
    [ ! -f "$CONFIG_FILE" ] && { echo -e "${YELLOW}Creating default bot_config.py...${NC}"; cat > "$CONFIG_FILE" << EOF
TOKEN = "SET_YOUR_TOKEN"
ADMIN_IDS = [123456789]
DB_PATH = "bot_data.db"
CACHE_DURATION = 30
VERSION = "V1.1.3"
EOF
    }
    sed -i "s|^TOKEN\s*=\s*['\"].*['\"]|TOKEN = \"$TOKEN\"|" "$CONFIG_FILE"
    sed -i "s|^ADMIN_IDS\s*=\s*$$   .*   $$|ADMIN_IDS = [$ADMIN_ID]|" "$CONFIG_FILE"
    chmod 644 "$CONFIG_FILE"
    grep -q "TOKEN = \"$TOKEN\"" "$CONFIG_FILE" && grep -q "ADMIN_IDS = $$   $ADMIN_ID   $$" "$CONFIG_FILE" && echo -e "${GREEN}bot_config.py updated${NC}" || { echo -e "${RED}Failed to update bot_config.py${NC}"; exit 1; }
}

setup_data_directory() {
    echo -e "${YELLOW}Setting up database directory...${NC}"
    mkdir -p "$DATA_DIR"
    chmod 777 "$DATA_DIR"
    rm -f "$DB_FILE"
    echo -e "${GREEN}Database directory configured${NC}"
}

cleanup_docker() {
    echo -e "${YELLOW}Cleaning up Docker...${NC}"
    [ -f "$COMPOSE_FILE" ] && sudo docker-compose -f "$COMPOSE_FILE" down --volumes --rmi all 2>/dev/null || true
    sudo docker images -q -f "reference=$PROJECT_NAME" | sort -u | xargs -r sudo docker rmi 2>/dev/null || true
    sudo docker ps -a -q -f "name=$PROJECT_NAME" | xargs -r sudo docker rm 2>/dev/null || true
    echo -e "${GREEN}Docker cleanup completed${NC}"
}

check_container_status() {
    echo -e "${YELLOW}Checking container status...${NC}"
    sleep 5
    [ -n "$(sudo docker ps -q -f "name=$PROJECT_NAME")" ] && { echo -e "${GREEN}Container running${NC}"; return 0; } || { echo -e "${RED}Container failed to start${NC}"; sudo docker-compose logs; return 1; }
}
