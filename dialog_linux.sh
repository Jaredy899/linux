#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install dialog if it isn't already installed
if ! command_exists dialog; then
    echo "dialog is not installed. Installing dialog..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian)
                sudo apt-get update -qq
                sudo apt-get install -y dialog -qq
                ;;
            fedora)
                sudo dnf install -y dialog -q
                ;;
            centos|rhel)
                sudo yum install -y dialog -q
                ;;
            arch)
                sudo pacman -Sy dialog --noconfirm >/dev/null
                ;;
            *)
                echo "Unsupported distro. Please install dialog manually."
                exit 1
                ;;
        esac
    else
        echo "Could not detect the operating system. Please install dialog manually."
        exit 1
    fi
else
    echo "dialog is already installed."
fi

# Ensure git is installed
if ! command_exists git; then
    dialog --msgbox "Git is not installed. Installing git..." 8 40 --title "Installing Git"
    
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
                dialog --msgbox "Unsupported distro. Please install git manually." 8 40 --title "Error"
                exit 1
                ;;
        esac
    else
        dialog --msgbox "Could not detect the operating system. Please install git manually." 8 40 --title "Error"
        exit 1
    fi
else
    dialog --msgbox "Git is already installed." 8 40 --title "Info"
fi

# Check if the system is Ubuntu and add the PPA if it is
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "$ID" = "ubuntu" ]; then
        dialog --msgbox "Ubuntu detected. Adding the PPA for fastfetch..." 8 40 --title "Adding PPA"
        sudo add-apt-repository ppa:zhangsongcui3371/fastfetch -y
    fi
fi

# Main menu
while true; do
    CHOICE=$(dialog --title "Setup Script" --menu "Choose an option:" 15 60 7 \
    1 "Start ChrisTitusTech script" \
    2 "Fix bashrc" \
    3 "Install Cockpit" \
    4 "Install Network Drive" \
    5 "Install qemu-guest-agent" \
    6 "Install Docker and Portainer" \
    7 "Exit" 3>&1 1>&2 2>&3)
    
    case $CHOICE in
        1)
            dialog --yesno "Do you want to start the ChrisTitusTech script?" 8 40 --title "Confirmation"
            if [ $? -eq 0 ]; then
                bash -c "$(curl -fsSL https://christitus.com/linux)"
            else
                dialog --msgbox "ChrisTitusTech script not started." 8 40 --title "Info"
            fi
            ;;
        2)
            dialog --yesno "Do you want to fix bashrc?" 8 40 --title "Confirmation"
            if [ $? -eq 0 ]; then
                bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/fix_bashrc.sh)"
            else
                dialog --msgbox ".bashrc not fixed." 8 40 --title "Info"
            fi
            ;;
        3)
            dialog --yesno "Do you want to install Cockpit?" 8 40 --title "Confirmation"
            if [ $? -eq 0 ]; then
                bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/cockpit.sh)"
            else
                dialog --msgbox "Cockpit not installed." 8 40 --title "Info"
            fi
            ;;
        4)
            dialog --yesno "Do you want to install a network drive?" 8 40 --title "Confirmation"
            if [ $? -eq 0 ]; then
                bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/add_network_drive.sh)"
            else
                dialog --msgbox "Network drive not installed." 8 40 --title "Info"
            fi
            ;;
        5)
            dialog --yesno "Do you want to install qemu-guest-agent?" 8 40 --title "Confirmation"
            if [ $? -eq 0 ]; then
                bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/qemu-guest-agent.sh)"
            else
                dialog --msgbox "qemu-guest-agent not installed." 8 40 --title "Info"
            fi
            ;;
        6)
            dialog --yesno "Do you want to install Docker and Portainer?" 8 40 --title "Confirmation"
            if [ $? -eq 0 ]; then
                bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/docker.sh)"
            else
                dialog --msgbox "Docker and Portainer not installed." 8 40 --title "Info"
            fi
            ;;
        7)
            break
            ;;
        *)
            dialog --msgbox "Invalid option!" 8 40 --title "Error"
            ;;
    esac
done

# Clear the screen after exiting
clear
