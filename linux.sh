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
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian)
                sudo apt-get update -qq
                sudo apt-get install -y git -qq
                ;;
            fedora)
                sudo dnf install -y git -q
                ;;
            centos|rhel)
                sudo yum install -y git -q
                ;;
            arch)
                sudo pacman -Sy git --noconfirm >/dev/null
                ;;
            *)
                echo "Unsupported distro. Please install git manually."
                exit 1
                ;;
        esac
    else
        echo "Could not detect the operating system. Please install git manually."
        exit 1
    fi
else
    echo "Git is already installed."
fi

# Check if the system is Ubuntu and add the PPA if it is
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "$ID" = "ubuntu" ]; then
        echo "Ubuntu detected. Adding the PPA for fastfetch..."
        sudo add-apt-repository ppa:zhangsongcui3371/fastfetch -y
    fi
fi

# Ask the user if they want to start the ChrisTitusTech script
response=$(get_user_input "Do you want to start the ChrisTitusTech script? (y/n): " "n")

if [ "$response" = "y" ]; then
    curl -fsSL https://christitus.com/linux | sh
else
    echo "ChrisTitusTech script not started."
fi

# Ask the user if they want to fix .bashrc
bashrc_response=$(get_user_input "Do you want to fix bashrc? (y/n): " "n")

if [ "$bashrc_response" = "y" ]; then
    curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/fix_bashrc.sh | sh
else
    echo ".bashrc not fixed."
fi

# Ask the user if they want to install Cockpit
cockpit_response=$(get_user_input "Do you want to install Cockpit? (y/n): " "n")

if [ "$cockpit_response" = "y" ]; then
    curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/cockpit.sh | sh
else
    echo "Cockpit not installed."
fi

# Ask the user if they want to install a network drive
network_drive_response=$(get_user_input "Do you want to install a network drive? (y/n): " "n")

if [ "$network_drive_response" = "y" ]; then
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/add_network_drive.sh)
else
    echo "Network drive not installed."
fi

# Ask the user if they want to install Docker and Portainer
docker_response=$(get_user_input "Do you want to install Docker and Portainer? (y/n): " "n")

if [ "$docker_response" = "y" ]; then
    curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/docker.sh | sh
else
    echo "Docker and Portainer not installed."
fi
