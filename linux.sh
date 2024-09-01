#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status
IFS=$(printf '\n\t')

# Set the GITPATH variable to the directory where the script is located
GITPATH="$(cd "$(dirname "$0")" && pwd)"
echo "GITPATH is set to: $GITPATH"

# GitHub URL base for the necessary configuration files
GITHUB_BASE_URL="https://raw.githubusercontent.com/Jaredy899/linux/main"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to run a script from local or GitHub
run_script() {
    script_name="$1"
    local_path="$2"
    url="$3"

    if [[ -f "$local_path/$script_name" ]]; then
        echo "Running $script_name from local directory..."
        bash "$local_path/$script_name"
    else
        echo "Running $script_name from GitHub..."
        curl -fsSL "$url/$script_name" -o "/tmp/$script_name"
        bash "/tmp/$script_name"
        rm "/tmp/$script_name"
    fi
}

# Ensure git is installed
if ! command_exists git; then
    echo "Git is not installed. Installing git..."
    run_script "install.git.sh" "$GITPATH" "$GITHUB_BASE_URL"
else
    echo "Git is already installed."
fi

# Check if the system is Debian, Ubuntu, or Arch
SHOW_OPTIONS_8_9=false
DWM_SETUP_SCRIPT=""
AUTO_LOGIN_SCRIPT=""

if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" == "debian" || "$ID" == "ubuntu" ]]; then
        SHOW_OPTIONS_8_9=true
        DWM_SETUP_SCRIPT="debian_dwm_setup.sh"
        AUTO_LOGIN_SCRIPT="debian_ubuntu_auto_login.sh"
        if command_exists fastfetch; then
            echo "Fastfetch is already installed. Skipping installation."
        else
            echo "Fastfetch is not installed. Proceeding to install fastfetch..."
            run_script "install_fastfetch.sh" "$GITPATH" "$GITHUB_BASE_URL"
        fi
    elif [[ "$ID" == "arch" ]]; then
        SHOW_OPTIONS_8_9=true
        DWM_SETUP_SCRIPT="arch_dwm_setup.sh"
        AUTO_LOGIN_SCRIPT="arch_auto_login.sh"  # Renamed from auto_login.sh
    else
        echo "This is not a Debian/Ubuntu/Arch system. Skipping specific installations and proceeding..."
    fi
else
    echo "Cannot detect the operating system. /etc/os-release not found. Skipping specific installations and proceeding..."
fi

# Menu loop
while true; do
    echo "#############################"
    echo "##    Select an option:    ##"
    echo "#############################"
    echo "1) Run ChrisTitusTech script"
    echo "2) Install ncdu"
    echo "3) Install Cockpit"
    echo "4) Install a network drive"
    echo "5) Install qemu-guest-agent"
    echo "6) Install Tailscale"
    echo "7) Install Docker and Portainer"
    
    if $SHOW_OPTIONS_8_9; then
        echo "8) Run DWM Setup Script"
        echo "9) Configure Auto-Login and StartX"
    fi

    echo "0) Exit"
    echo

    if $SHOW_OPTIONS_8_9; then
        read -p "Enter your choice (0-9): " choice
    else
        read -p "Enter your choice (0-7): " choice
    fi

    case $choice in
        1) 
            echo "Running Chris Titus Tech's script..."
            curl -fsSL christitus.com/linux | sh
            ;;
        2) run_script "install_ncdu.sh" "$GITPATH" "$GITHUB_BASE_URL" ;;
        3) run_script "cockpit.sh" "$GITPATH" "$GITHUB_BASE_URL" ;;
        4) run_script "add_network_drive.sh" "$GITPATH" "$GITHUB_BASE_URL" ;;
        5) run_script "qemu-guest-agent.sh" "$GITPATH" "$GITHUB_BASE_URL" ;;
        6) 
            echo "Installing Tailscale..."
            curl -fsSL https://tailscale.com/install.sh | sh
            echo "Tailscale installed. Please run 'sudo tailscale up' to activate."
            ;;
        7) run_script "docker.sh" "$GITPATH" "$GITHUB_BASE_URL" ;;
        8)
            if $SHOW_OPTIONS_8_9; then
                echo "Running DWM Setup Script..."
                run_script "$DWM_SETUP_SCRIPT" "$GITPATH" "$GITHUB_BASE_URL"
            else
                echo "Invalid option. Please enter a number between 0 and 7."
            fi
            ;;
        9)
            if $SHOW_OPTIONS_8_9; then
                echo "Configuring Auto-Login and StartX..."
                run_script "$AUTO_LOGIN_SCRIPT" "$GITPATH" "$GITHUB_BASE_URL"
            else
                echo "Invalid option. Please enter a number between 0 and 7."
            fi
            ;;
        0) echo "Exiting script."; break ;;
        *) echo "Invalid option. Please enter a number between 0 and $(if $SHOW_OPTIONS_8_9; then echo "9"; else echo "7"; fi)." ;;
    esac
done

echo "#############################"
echo "##                         ##"
echo "## Setup script completed. ##"
echo "##                         ##"
echo "#############################"