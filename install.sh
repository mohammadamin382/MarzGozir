#!/bin/bash

# Function to check and install prerequisites
install_prerequisites() {
    echo "Checking and installing prerequisites..."
    local packages=("python3" "python3-pip" "python3-venv" "git")
    local missing=()

    # Check for missing packages
    for pkg in "${packages[@]}"; do
        if ! command -v "$pkg" &> /dev/null; then
            missing+=("$pkg")
        fi
    done

    # Install missing packages
    if [ ${#missing[@]} -ne 0 ]; then
        echo "Installing missing packages: ${missing[*]}"
        sudo apt update
        for pkg in "${missing[@]}"; do
            sudo apt install -y "$pkg"
        done
    else
        echo "All prerequisites are already installed."
    fi
}

# Function to display the menu
show_menu() {
    clear
    echo "================================="
    echo "      MarzGozir Bot Manager      "
    echo "================================="
    echo "1. Install Bot"
    echo "2. Update Bot"
    echo "3. Change Token and Admin ID"
    echo "4. Remove Bot"
    echo "5. Exit"
    echo "================================="
    echo -n "Please select an option (1-5): "
}

# Function to install the bot
install_bot() {
    echo "Starting bot installation..."
    # Install prerequisites
    install_prerequisites

    # Create directory and clone repository
    sudo mkdir -p /opt/MahYaR
    cd /opt/MahYaR
    if [ -d "MarzGozir" ]; then
        echo "MarzGozir directory already exists. Removing and reinstalling..."
        sudo rm -rf MarzGozir
    fi
    sudo git clone https://github.com/mahyyar/MarzGozir.git
    cd MarzGozir

    # Create virtual environment and install dependencies
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt

    # Get token and admin ID
    read -p "Enter bot token: " token
    read -p "Enter admin ID: " admin_id

    # Create or update bot_config.py
    cat > bot_config.py << EOL
TOKEN = "$token"
ADMIN_ID = $admin_id
EOL

    # Run the bot in the background
    nohup python3 bot.py > bot.log 2>&1 &
    echo "Bot installed and started successfully!"
    read -p "Press Enter to return to the menu..."
}

# Function to update the bot
update_bot() {
    echo "Starting bot update..."
    if [ ! -d "/opt/MahYaR/MarzGozir" ]; then
        echo "Bot is not installed! Please install the bot first."
        read -p "Press Enter to return to the menu..."
        return
    fi

    cd /opt/MahYaR/MarzGozir
    git pull origin main
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt

    # Restart the bot
    pkill -f "python3 bot.py"
    nohup python3 bot.py > bot.log 2>&1 &
    echo "Bot updated and restarted successfully!"
    read -p "Press Enter to return to the menu..."
}

# Function to change token and admin ID
change_config() {
    if [ ! -f "/opt/MahYaR/MarzGozir/bot_config.py" ]; then
        echo "Configuration file not found! Please install the bot first."
        read -p "Press Enter to return to the menu..."
        return
    fi

    read -p "Enter new bot token: " token
    read -p "Enter new admin ID: " admin_id

    # Update bot_config.py
    cat > /opt/MahYaR/MarzGozir/bot_config.py << EOL
TOKEN = "$token"
ADMIN_ID = $admin_id
EOL

    # Restart the bot
    pkill -f "python3 bot.py"
    cd /opt/MahYaR/MarzGozir
    source venv/bin/activate
    nohup python3 bot.py > bot.log 2>&1 &
    echo "Token and Admin ID updated successfully!"
    read -p "Press Enter to return to the menu..."
}

# Function to remove the bot
remove_bot() {
    echo "Removing bot..."
    if [ ! -d "/opt/MahYaR" ]; then
        echo "Bot is not installed!"
        read -p "Press Enter to return to the menu..."
        return
    fi

    # Stop bot processes
    pkill -f "python3 bot.py"
    sudo rm -rf /opt/MahYaR
    echo "Bot removed successfully!"
    read -p "Press Enter to return to the menu..."
}

# Main loop
while true; do
    show_menu
    read choice
    case $choice in
        1)
            install_bot
            ;;
        2)
            update_bot
            ;;
        3)
            change_config
            ;;
        4)
            remove_bot
            ;;
        5)
            clear
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option! Please select a number between 1 and 5."
            read -p "Press Enter to continue..."
            ;;
    esac
done
