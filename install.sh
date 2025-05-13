#!/bin/bash

# Script for installing, updating, and configuring MarzGozir bot in /opt/mahyar on Ubuntu

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running on Ubuntu
if ! lsb_release -a 2>/dev/null | grep -q "Ubuntu"; then
    echo -e "${RED}This script is designed to run only on Ubuntu servers.${NC}"
    exit 1
fi

# Check if script is run with sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run this script as root (use sudo).${NC}"
    exit 1
fi

# Check and install prerequisites
install_prerequisites() {
    echo -e "${YELLOW}Checking and installing prerequisites...${NC}"
    apt-get update
    apt-get install -y git python3 python3-pip python3-venv
}

# Function to install the bot
install_bot() {
    echo -e "${GREEN}Installing MarzGozir bot in /opt/mahyar...${NC}"
    
    # Create directory if it doesn't exist
    mkdir -p /opt/mahyar
    cd /opt/mahyar || exit
    
    # Clone the repository if not already cloned
    if [ ! -d "MarzGozir" ]; then
        git clone https://github.com/mahyyar/MarzGozir.git
    else
        echo -e "${YELLOW}MarzGozir directory already exists. Skipping clone.${NC}"
    fi
    
    cd MarzGozir || exit
    
    # Create and activate virtual environment
    python3 -m venv venv
    source venv/bin/activate
    
    # Install dependencies
    pip install --upgrade pip
    pip install -r requirements.txt
    
    # Create bot_config.py if it doesn't exist
    if [ ! -f "bot_config.py" ]; then
        echo -e "${YELLOW}Creating bot_config.py template...${NC}"
        cat << EOF > bot_config.py
# Configuration file for MarzGozir bot
BOT_TOKEN = "YOUR_BOT_TOKEN_HERE"
ADMIN_ID = 0  # Replace with your numeric admin ID
EOF
    fi
    
    # Set proper permissions
    chown -R root:root /opt/mahyar
    chmod -R 755 /opt/mahyar
    
    echo -e "${GREEN}Bot installed successfully. Please edit /opt/mahyar/MarzGozir/bot_config.py with your BOT_TOKEN and ADMIN_ID.${NC}"
}

# Function to update the bot
update_bot() {
    echo -e "${GREEN}Updating MarzGozir bot...${NC}"
    
    if [ ! -d "/opt/mahyar/MarzGozir" ]; then
        echo -e "${RED}Bot is not installed. Please install it first.${NC}"
        exit 1
    fi
    
    cd /opt/mahyar/MarzGozir || exit
    git pull origin main
    
    # Activate virtual environment and update dependencies
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt --upgrade
    
    echo -e "${GREEN}Bot updated successfully.${NC}"
}

# Function to edit token and ID
edit_config() {
    echo -e "${GREEN}Editing BOT_TOKEN and ADMIN_ID in bot_config.py...${NC}"
    
    if [ ! -f "/opt/mahyar/MarzGozir/bot_config.py" ]; then
        echo -e "${RED}bot_config.py not found. Please install the bot first.${NC}"
        exit 1
    fi
    
    # Prompt for new token and ID
    read -p "Enter your Bot Token: " bot_token
    read -p "Enter your numeric Admin ID: " admin_id
    
    # Validate admin_id is numeric
    if ! [[ "$admin_id" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Admin ID must be a numeric value.${NC}"
        exit 1
    fi
    
    # Update bot_config.py
    sed -i "s/BOT_TOKEN = .*/BOT_TOKEN = \"$bot_token\"/" /opt/mahyar/MarzGozir/bot_config.py
    sed -i "s/ADMIN_ID = .*/ADMIN_ID = $admin_id/" /opt/mahyar/MarzGozir/bot_config.py
    
    echo -e "${GREEN}Configuration updated successfully in /opt/mahyar/MarzGozir/bot_config.py.${NC}"
}

# Main menu
while true; do
    echo -e "${YELLOW}=== MarzGozir Bot Setup Menu ===${NC}"
    echo "1. Install Bot"
    echo "2. Update Bot"
    echo "3. Edit Token and ID"
    echo "4. Exit"
    read -p "Choose an option (1-4): " choice
    
    case $choice in
        1)
            install_prerequisites
            install_bot
            ;;
        2)
            update_bot
            ;;
        3)
            edit_config
            ;;
        4)
            echo -e "${GREEN}Exiting...${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option. Please choose 1, 2, 3, or 4.${NC}"
            ;;
    esac
done
