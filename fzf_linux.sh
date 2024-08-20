#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install fzf if it isn't already installed
if ! command_exists fzf; then
    echo "fzf is not installed. Installing fzf..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian)
                sudo apt-get update -qq
                sudo apt-get install -y fzf -qq
                ;;
            fedora)
                sudo dnf install -y fzf -q
                ;;
            centos|rhel)
                sudo yum install -y fzf -q
                ;;
            arch)
                sudo pacman -Sy fzf --noconfirm >/dev/null
                ;;
            *)
                echo "Unsupported distro. Please install fzf manually."
                exit 1
                ;;
        esac
    else
        echo "Could not detect the operating system. Please install fzf manually."
        exit 1
    fi
else
    echo "fzf is already installed."
fi

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

# Define the options for fzf selection
options=(
    "1 Start ChrisTitusTech script"
    "2 Fix bashrc"
    "3 Install Cockpit"
    "4 Install Network Drive"
    "5 Install qemu-guest-agent"
    "6 Install Docker and Portainer"
    "7 Exit"
)

# Use fzf for menu selection
CHOICE=$(printf "%s\n" "${options[@]}" | fzf --height 15 --border --prompt "Choose an option: ")

case $CHOICE in
    "1 Start ChrisTitusTech script")
        read -p "Do you want to start the ChrisTitusTech script? (y/n): " response
        if [ "$response" = "y" ]; then
            bash -c "$(curl -fsSL https://christitus.com/linux)"
        else
            echo "ChrisTitusTech script not started."
        fi
        ;;
    "2 Fix bashrc")
        read -p "Do you want to fix bashrc? (y/n): " bashrc_response
        if [ "$bashrc_response" = "y" ]; then
            bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/fix_bashrc.sh)"
        else
            echo ".bashrc not fixed."
        fi
        ;;
    "3 Install Cockpit")
        read -p "Do you want to install Cockpit? (y/n): " cockpit_response
        if [ "$cockpit_response" = "y" ]; then
            bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/cockpit.sh)"
        else
            echo "Cockpit not installed."
        fi
        ;;
    "4 Install Network Drive")
        read -p "Do you want to install a network drive? (y/n): " network_drive_response
        if [ "$network_drive_response" = "y" ]; then
            bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/add_network_drive.sh)"
        else
            echo "Network drive not installed."
        fi
        ;;
    "5 Install qemu-guest-agent")
        read -p "Do you want to install qemu-guest-agent? (y/n): " qemu_guest_agent_response
        if [ "$qemu_guest_agent_response" = "y" ]; then
            bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/qemu-guest-agent.sh)"
        else
            echo "qemu-guest-agent not installed."
        fi
        ;;
    "6 Install Docker and Portainer")
        read -p "Do you want to install Docker and Portainer? (y/n): " docker_response
        if [ "$docker_response" = "y" ]; then
            bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/docker.sh)"
        else
            echo "Docker and Portainer not installed."
        fi
        ;;
    "7 Exit")
        echo "Exiting script."
        exit 0
        ;;
    *)
        echo "Invalid option!"
        ;;
esac
