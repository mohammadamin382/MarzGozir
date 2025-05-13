#!/bin/bash

# Script for installing, updating, and configuring MarzGozir bot

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if script is run with sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run this script as root (use sudo).${NC}"
    exit 1
fi

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo -e "${YELLOW}Git is not installed. Installing git...${NC}"
    apt-get update && apt-get install -y git
fi

# Check if python3 and pip are installed
if ! command -v python3 &> /dev/null; then
    echo -e "${YELLOW}Python3 is not installed. Installing python3...${NC}"
    apt-get install -y python3 python3-pip
fi

# Function to install the bot
install_bot() {
    echo -e "${GREEN}Installing MarzGozir bot...${NC}"
    
    # Clone the repository if not already cloned
    if [ ! -d "MarzGozir" ]; then
        git clone https://github.com/mahyyar/MarzGozir.git
    fi
    
    cd MarzGozir || exit
    
    # Install dependencies
    pip3 install -r requirements.txt
    
    # Check if config file exists, if not create a template
    if [ ! -f "config.py" ]; then
        echo -e "${YELLOW}Creating config.py template...${NC}"
        cat << EOF > config.py
# Configuration file for MarzGozir bot
BOT_TOKEN = "YOUR_BOT_TOKEN_HERE"
ADMIN_ID = "YOUR_ADMIN_ID_HERE"
EOF
    fi
    
    echo -e "${GREEN}Bot installed successfully. Please edit config.py with your BOT_TOKEN and ADMIN_ID.${NC}"
}

# Function to update the bot
update_bot() {
    echo -e "${GREEN}Updating MarzGozir bot...${NC}"
    
    if [ ! -d "MarzGozir" ]; then
        echo -e "${RED}Bot is not installed. Please install it first.${NC}"
        exit 1
    fi
    
    cd MarzGozir || exit
    git pull origin main
    pip3 install -r requirements.txt --upgrade
    
    echo -e "${GREEN}Bot updated successfully.${NC}"
}

# Function to edit token and ID
edit_config() {
    echo -e "${GREEN}Editing BOT_TOKEN and ADMIN_ID...${NC}"
    
    if [ ! -f "MarzGozir/config.py" ]; then
        echo -e "${RED}config.py not found. Please install the bot first.${NC}"
        exit 1
    fi
    
    # Prompt for new token and ID
    read -p "Enter your Bot Token: " bot_token
    read -p "Enter your Admin ID: " admin_id
    
    # Update config.py
    sed -i "s/BOT_TOKEN = .*/BOT_TOKEN = \"$bot_token\"/" MarzGozir/config.py
    sed -i "s/ADMIN_ID = .*/ADMIN_ID = \"$admin_id\"/" MarzGozir/config.py
    
    echo -e "${GREEN}Configuration updated successfully.${NC}"
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
