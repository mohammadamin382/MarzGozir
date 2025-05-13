#!/bin/bash

install_prerequisites() {
    echo "Checking and installing prerequisites..."
    local packages=("python3" "python3-pip" "python3-venv" "git")
    local missing=()
    for pkg in "${packages[@]}"; do
        if ! command -v "$pkg" &> /dev/null; then
            missing+=("$pkg")
        fi
    done
    if [ ${#missing[@]} -ne 0 ]; then
        echo "Installing missing packages: ${missing[*]}"
        sudo apt update
        sudo apt install -y "${missing[@]}"
    else
        echo "All prerequisites are already installed."
    fi
    python3 --version
    pip3 --version
}

check_bot_status() {
    if pgrep -f "python3 bot.py" > /dev/null; then
        echo "Bot is running."
        return 0
    else
        echo "Bot is not running. Checking logs for errors..."
        if [ -f "/opt/MahYaR/MarzGozir/bot.log" ]; then
            echo "Last 10 lines of bot.log:"
            tail -n 10 /opt/MahYaR/MarzGozir/bot.log
        else
            echo "No log file found at /opt/MahYaR/MarzGozir/bot.log"
        fi
        return 1
    fi
}

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

install_bot() {
    echo "Starting bot installation..."
    install_prerequisites
    sudo mkdir -p /opt/MahYaR
    cd /opt/MahYaR
    if [ -d "MarzGozir" ]; then
        echo "MarzGozir directory already exists. Removing and reinstalling..."
        sudo rm -rf MarzGozir
    fi
    sudo git clone https://github.com/mahyyar/MarzGozir.git
    cd MarzGozir
    if [ ! -f "bot.py" ] || [ ! -f "requirements.txt" ]; then
        echo "Error: bot.py or requirements.txt not found in the repository!"
        read -p "Press Enter to return to the menu..."
        return 1
    fi
    python3 -m venv venv
    source venv/bin/activate
    if ! pip install --upgrade pip; then
        echo "Error: Failed to upgrade pip."
        read -p "Press Enter to return to the menu..."
        return 1
    fi
    if ! pip install -r requirements.txt; then
        echo "Error: Failed to install dependencies. Check requirements.txt."
        read -p "Press Enter to return to the menu..."
        return 1
    fi
    read -p "Enter bot token: " token
    read -p "Enter admin ID: " admin_id
    cat > bot_config.py << EOL
TOKEN = "$token"
ADMIN_ID = $admin_id
EOL
    nohup python3 bot.py > bot.log 2>&1 &
    sleep 2
    if check_bot_status; then
        echo "Bot installed and started successfully!"
    else
        echo "Failed to start the bot. Please check the logs."
    fi
    read -p "Press Enter to return to the menu..."
}

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
    if ! pip install --upgrade pip; then
        echo "Error: Failed to upgrade pip."
        read -p "Press Enter to return to the menu..."
        return 1
    fi
    if ! pip install -r requirements.txt; then
        echo "Error: Failed to install dependencies. Check requirements.txt."
        read -p "Press Enter to return to the menu..."
        return 1
    fi
    pkill -f "python3 bot.py"
    nohup python3 bot.py > bot.log 2>&1 &
    sleep 2
    if check_bot_status; then
        echo "Bot updated and restarted successfully!"
    else
        echo "Failed to restart the bot. Please check the logs."
    fi
    read -p "Press Enter to return to the menu..."
}

change_config() {
    if [ ! -f "/opt/MahYaR/MarzGozir/bot_config.py" ]; then
        echo "Configuration file not found! Please install the bot first."
        read -p "Press Enter to return to the menu..."
        return
    fi
    read -p "Enter new bot token: " token
    read -p "Enter new admin ID: " admin_id
    cat > /opt/MahYaR/MarzGozir/bot_config.py << EOL
TOKEN = "$token"
ADMIN_ID = $admin_id
EOL
    pkill -f "python3 bot.py"
    cd /opt/MahYaR/MarzGozir
    source venv/bin/activate
    nohup python3 bot.py > bot.log 2>&1 &
    sleep 2
    if check_bot_status; then
        echo "Token and Admin ID updated successfully!"
    else
        echo "Failed to restart the bot. Please check the logs."
    fi
    read -p "Press Enter to return to the menu..."
}

remove_bot() {
    echo "Removing bot..."
    if [ ! -d "/opt/MahYaR" ]; then
        echo "Bot is not installed!"
        read -p "Press Enter to return to the menu..."
        return
    fi
    pkill -f "python3 bot.py"
    sudo rm -rf /opt/MahYaR
    echo "Bot removed successfully!"
    read -p "Press Enter to return to the menu..."
}

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
