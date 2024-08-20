#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Ensure whiptail is installed
if ! command_exists whiptail; then
    echo "whiptail is not installed. Installing whiptail..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian)
                sudo apt-get update -qq
                sudo apt-get install -y whiptail -qq
                ;;
            fedora)
                sudo dnf install -y newt -q
                ;;
            centos|rhel)
                sudo yum install -y newt -q
                ;;
            arch)
                if command_exists yay; then
                    yay -S --noconfirm newt
                else
                    echo "Please install 'newt' from the AUR manually or use an AUR helper like 'yay'."
                    exit 1
                fi
                ;;
            *)
                echo "Unsupported distro. Please install whiptail manually."
                exit 1
                ;;
        esac
    else
        echo "Could not detect the operating system. Please install whiptail manually."
        exit 1
    fi
else
    echo "whiptail is already installed."
fi

# Check if git is installed, and install if necessary
if ! command_exists git; then
    whiptail --msgbox "Git is not installed. Installing git..." 8 78 --title "Installing Git"
    
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
                whiptail --msgbox "Unsupported distro. Please install git manually." 8 78 --title "Error"
                exit 1
                ;;
        esac
    else
        whiptail --msgbox "Could not detect the operating system. Please install git manually." 8 78 --title "Error"
        exit 1
    fi
else
    whiptail --msgbox "Git is already installed." 8 78 --title "Info"
fi

# Check if the system is Ubuntu and add the PPA if it is
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "$ID" = "ubuntu" ]; then
        whiptail --msgbox "Ubuntu detected. Adding the PPA for fastfetch..." 8 78 --title "Adding PPA"
        sudo add-apt-repository ppa:zhangsongcui3371/fastfetch -y
    fi
fi

# Main menu
while true; do
    CHOICE=$(whiptail --title "Setup Script" --menu "Choose an option:" 15 60 7 \
    "1" "Start ChrisTitusTech script" \
    "2" "Fix bashrc" \
    "3" "Install Cockpit" \
    "4" "Install Network Drive" \
    "5" "Install qemu-guest-agent" \
    "6" "Install Docker and Portainer" \
    "7" "Exit" 3>&1 1>&2 2>&3)
    
    case $CHOICE in
        "1")
            response=$(whiptail --yesno "Do you want to start the ChrisTitusTech script?" 8 78 --title "Confirmation" 3>&1 1>&2 2>&3)
            if [ $? -eq 0 ]; then
                bash -c "$(curl -fsSL https://christitus.com/linux)"
            else
                whiptail --msgbox "ChrisTitusTech script not started." 8 78 --title "Info"
            fi
            ;;
        "2")
            bashrc_response=$(whiptail --yesno "Do you want to fix bashrc?" 8 78 --title "Confirmation" 3>&1 1>&2 2>&3)
            if [ $? -eq 0 ]; then
                bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/fix_bashrc.sh)"
            else
                whiptail --msgbox ".bashrc not fixed." 8 78 --title "Info"
            fi
            ;;
        "3")
            cockpit_response=$(whiptail --yesno "Do you want to install Cockpit?" 8 78 --title "Confirmation" 3>&1 1>&2 2>&3)
            if [ $? -eq 0 ]; then
                bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/cockpit.sh)"
            else
                whiptail --msgbox "Cockpit not installed." 8 78 --title "Info"
            fi
            ;;
        "4")
            network_drive_response=$(whiptail --yesno "Do you want to install a network drive?" 8 78 --title "Confirmation" 3>&1 1>&2 2>&3)
            if [ $? -eq 0 ]; then
                bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/add_network_drive.sh)"
            else
                whiptail --msgbox "Network drive not installed." 8 78 --title "Info"
            fi
            ;;
        "5")
            qemu_guest_agent_response=$(whiptail --yesno "Do you want to install qemu-guest-agent?" 8 78 --title "Confirmation" 3>&1 1>&2 2>&3)
            if [ $? -eq 0 ]; then
                bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/qemu-guest-agent.sh)"
            else
                whiptail --msgbox "qemu-guest-agent not installed." 8 78 --title "Info"
            fi
            ;;
        "6")
            docker_response=$(whiptail --yesno "Do you want to install Docker and Portainer?" 8 78 --title "Confirmation" 3>&1 1>&2 2>&3)
            if [ $? -eq 0 ]; then
                bash -c "$(curl -fsSL https://raw.githubusercontent.com/Jaredy899/linux/main/docker.sh)"
            else
                whiptail --msgbox "Docker and Portainer not installed." 8 78 --title "Info"
            fi
            ;;
        "7")
            break
            ;;
        *)
            whiptail --msgbox "Invalid option!" 8 78 --title "Error"
            ;;
    esac
done
