#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to capture user input
get_user_input() {
    prompt="$1"
    default="$2"
    read -r -p "$prompt" response
    if [ -z "$response" ]; then
        response="$default"
    fi
    echo "$response"
}

# Function to display a menu and handle user choices
show_menu() {
    echo "#############################"
    echo "##   Select an option:     ##"
    echo "#############################"
    echo "1) Run ChrisTitusTech script"
    echo "2) Fix .bashrc"
    echo "3) Replace fastfetch with Jared's custom one"
    echo "4) Replace starship with Jared's custom one"
    echo "5) Install ncdu"
    echo "6) Install Cockpit"
    echo "7) Install a network drive"
    echo "8) Install qemu-guest-agent"
    echo "9) Install Tailscale"
    echo "10) Install Docker and Portainer"
    echo "0) Exit"
    echo

    read -p "Enter your choice (0-10): " choice
    return $choice
}

# Ensure git is installed
if ! command_exists git; then
    echo "Git is not installed. Installing git..."
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/install.git.sh)"
else
    echo "Git is already installed."
fi

# Check if the system is Ubuntu or Debian
if [ -f /etc/os-release ]; then
    . /etc/os-release

    # If the system is Ubuntu
    if [ "$ID" = "ubuntu" ]; then
        if ! grep -q "^deb .*$ID/fastfetch" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
            echo "Adding fastfetch PPA for Ubuntu..."
            sudo add-apt-repository ppa:zhangsongcui3371/fastfetch -y >/dev/null 2>&1
        else
            echo "fastfetch PPA is already added for Ubuntu."
        fi
    fi

    # If the system is Debian
    if [ "$ID" = "debian" ]; then
        # Fetch the latest fastfetch release URL for linux-amd64 deb file
        FASTFETCH_URL=$(curl -s https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest | grep "browser_download_url.*linux-amd64.deb" | cut -d '"' -f 4)

        if [ -n "$FASTFETCH_URL" ]; then
            echo "Downloading the latest fastfetch release for Debian..."
            curl -sL "$FASTFETCH_URL" -o /tmp/fastfetch_latest_amd64.deb

            echo "Installing fastfetch on Debian..."
            sudo apt-get install /tmp/fastfetch_latest_amd64.deb -y
        else
            echo "Failed to fetch the latest fastfetch release URL for Debian."
        fi
    fi
fi

# Menu loop
while true; do
    show_menu
    choice=$?

    case $choice in
        1)
            echo "Running ChrisTitusTech script..."
            bash -c "$(curl -fsSL https://christitus.com/linux)"
            ;;
        2)
            echo "Fixing .bashrc..."
            bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/fix_bashrc.sh)"
            ;;
        3)
            echo "Replacing fastfetch with Jared's custom one..."
            bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/replace_config_jsonc.sh)"
            ;;
        4)
            echo "Replacing starship with Jared's custom one..."
            bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/replace_starship_toml.sh)"
            ;;
        5)
            echo "Installing ncdu..."
            sudo apt-get update >/dev/null 2>&1
            sudo apt-get install ncdu -y >/dev/null 2>&1
            echo "ncdu installed successfully."
            ;;
        6)
            echo "Installing Cockpit..."
            bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/cockpit.sh)"
            ;;
        7)
            echo "Installing a network drive..."
            bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/add_network_drive.sh)"
            ;;
        8)
            echo "Installing qemu-guest-agent..."
            bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/qemu-guest-agent.sh)"
            ;;
        9)
            echo "Installing Tailscale..."
            curl -fsSL https://tailscale.com/install.sh | sh
            ;;
        10)
            echo "Installing Docker and Portainer..."
            bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/docker.sh)"
            ;;
        0)
            echo "Exiting script."
            break
            ;;
        *)
            echo "Invalid option. Please enter a number between 0 and 10."
            ;;
    esac
done

echo "#############################"
echo "##                         ##"
echo "## Setup script completed. ##"
echo "##                         ##"
echo "#############################"
