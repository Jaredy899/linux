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

# Ensure git is installed
if ! command_exists git; then
    echo "Git is not installed. Installing git..."
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/install.git.sh)"
else
    echo "Git is already installed."
fi

# Check if the system is Ubuntu and add the PPA if it is not already added
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "$ID" = "ubuntu" ]; then
        if ! grep -q "^deb .*$ID/fastfetch" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
            echo "Adding fastfetch PPA..."
            sudo add-apt-repository ppa:zhangsongcui3371/fastfetch -y >/dev/null 2>&1
        else
            echo "fastfetch PPA is already added."
        fi
    fi
fi

# Ask the user if they want to start the ChrisTitusTech script
response=$(get_user_input "Do you want to start the ChrisTitusTech script? (y/n): " "n")

if [ "$response" = "y" ]; then
    bash -c "$(curl -fsSL https://christitus.com/linux)"
else
    echo "ChrisTitusTech script not started."
fi

# Ask the user if they want to fix .bashrc
bashrc_response=$(get_user_input "Do you want to fix bashrc? (y/n): " "n")

if [ "$bashrc_response" = "y" ]; then
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/fix_bashrc.sh)"
else
    echo ".bashrc not fixed."
fi

# Ask the user if they want to install Cockpit
cockpit_response=$(get_user_input "Do you want to install Cockpit? (y/n): " "n")

if [ "$cockpit_response" = "y" ]; then
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/cockpit.sh)"
else
    echo "Cockpit not installed."
fi

# Ask the user if they want to install a network drive
network_drive_response=$(get_user_input "Do you want to install a network drive? (y/n): " "n")

if [ "$network_drive_response" = "y" ]; then
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/add_network_drive.sh)"
else
    echo "Network drive not installed."
fi

# Ask the user if they want to install qemu-guest-agent
qemu_guest_agent_response=$(get_user_input "Do you want to install qemu-guest-agent? (y/n): " "n")

if [ "$qemu_guest_agent_response" = "y" ]; then
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/qemu-guest-agent.sh)"
else
    echo "qemu-guest-agent not installed."
fi

# Ask the user if they want to install Docker and Portainer
docker_response=$(get_user_input "Do you want to install Docker and Portainer? (y/n): " "n")

if [ "$docker_response" = "y" ]; then
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/docker.sh)"
else
    echo "Docker and Portainer not installed."
fi

# Ask the user if they want to install Tailscale
tailscale_response=$(get_user_input "Do you want to install Tailscale? (y/n): " "n")

if [ "$tailscale_response" = "y" ]; then
    bash -c "$(curl -fsSL https://tailscale.com/install.sh | sh)"
else
    echo "Tailscale not installed."
fi
