#!/bin/sh

set -e  # Exit immediately if a command exits with a non-zero status
IFS='
	'

# Set the GITPATH variable to the directory where the script is located
if [ -f "$0" ]; then
    GITPATH=$(cd "$(dirname "$0")" && pwd)
else
    GITPATH="$HOME"
fi
echo "GITPATH is set to: $GITPATH"

# GitHub URL base for the necessary configuration files
GITHUB_BASE_URL="https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/dev/"
INSTALLS_URL="${GITHUB_BASE_URL}/installs"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to detect the Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

# Detect the Linux distribution
distro=$(detect_distro)
if [ "$distro" = "unknown" ]; then
    echo "Unable to detect Linux distribution. Exiting."
    exit 1
fi

# Function to run a script from local or GitHub
run_script() {
    script_name="$1"
    local_path="$2"
    url="$3"

    if [ -f "$local_path/$script_name" ]; then
        echo "Running $script_name from local directory..."
        bash "$local_path/$script_name"
    else
        echo "Running $script_name from GitHub..."
        curl -fsSL "$url/$script_name" -o "/tmp/$script_name"
        bash "/tmp/$script_name"
        rm "/tmp/$script_name"
    fi
}

# Check if running in an Arch Linux ISO environment
if [ -d /run/archiso/bootmnt ]; then
    echo "Arch Linux ISO environment detected."
    printf "Do you want to run the Arch install script? (y/n): "
    read -r run_install
    if [ "$run_install" = "y" ] || [ "$run_install" = "Y" ]; then
        run_script "arch_install.sh" "$GITPATH/installs" "$INSTALLS_URL"
    fi
fi

# Ensure git is installed
if ! command_exists git; then
    echo "Git is not installed. Installing git..."
    run_script "install_git.sh" "$GITPATH/installs" "$INSTALLS_URL"
else
    echo "Git is already installed."
fi

# Menu loop
while true; do
    echo "#############################"
    echo "##    Select an option:    ##"
    echo "#############################"
    echo "1) Run Post Install Script"
    echo "2) Run Chris Titus Tech Script"
    echo "3) Add SSH Key"
    echo "4) Install a network drive"
    echo "5) Install Cockpit"
    echo "6) Install Tailscale"
    echo "7) Install Docker and Portainer"
    echo "8) Run DWM Setup Script"
    echo "9) Replace configs"
    echo "0) Exit"
    echo

    printf "Enter your choice (0-9): "
    read -r choice

    case $choice in
        1) 
            echo "Running Post Install Script..."
            run_script "post_install.sh" "$GITPATH/installs" "$INSTALLS_URL"
            ;;
        2) 
            echo "Running Chris Titus Tech's script..."
            curl -fsSL christitus.com/linuxdev | sh
            ;;
        3) run_script "add_ssh_key.sh" "$GITPATH/installs" "$INSTALLS_URL" ;;
        4) run_script "add_network_drive.sh" "$GITPATH/installs" "$INSTALLS_URL" ;;
        5) 
            echo "Installing Cockpit..."
            run_script "cockpit.sh" "$GITPATH/installs" "$INSTALLS_URL"
            ;;
        6) 
            echo "Installing Tailscale..."
            curl -fsSL https://tailscale.com/install.sh | sh
            echo "Tailscale installed. Please run 'sudo tailscale up' to activate."
            ;;
        7) run_script "docker.sh" "$GITPATH/installs" "$INSTALLS_URL" ;;
        8) 
            echo "Running DWM Setup Script..."
            run_script "install_dwm.sh" "$GITPATH/installs" "$INSTALLS_URL"
            ;;
        9)
            echo "Replacing configs..."
            run_script "replace_configs.sh" "$GITPATH/installs" "$INSTALLS_URL"
            ;;
        0) echo "Exiting script."; break ;;
        *) echo "Invalid option. Please enter a number between 0 and 9." ;;
    esac
done

echo "#############################"
echo "##                         ##"
echo "## Setup script completed. ##"
echo "##                         ##"
echo "#############################"