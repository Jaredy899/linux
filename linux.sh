#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status
IFS=$(printf '\n\t')

# Set the GITPATH variable to the directory where the script is located
GITPATH="$(cd "$(dirname "$0")" && pwd)"
echo "GITPATH is set to: $GITPATH"

# GitHub URL base for the necessary configuration files
GITHUB_BASE_URL="https://raw.githubusercontent.com/Jaredy899/linux/dev"
INSTALLS_URL="$GITHUB_BASE_URL/installs"

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

# Check if running in an Arch Linux ISO environment
if [ -d /run/archiso/bootmnt ]; then
    echo "Arch Linux ISO environment detected."
    read -p "Do you want to run the dwm_setup.sh script? (y/n): " run_install
    if [[ "$run_install" =~ ^[Yy]$ ]]; then
        run_script "dwm_setup.sh" "$GITPATH/installs" "$INSTALLS_URL"
    fi
fi

# Ensure git is installed
if ! command_exists git; then
    echo "Git is not installed. Installing git..."
    run_script "install_git.sh" "$GITPATH/installs" "$INSTALLS_URL"
else
    echo "Git is already installed."
fi

# Check if the system is Debian/Ubuntu or Arch and install fastfetch if necessary
if [[ "$distro" == "debian" || "$distro" == "ubuntu" ]]; then
    if command_exists fastfetch; then
        echo "Fastfetch is already installed. Skipping installation."
    else
        echo "Fastfetch is not installed. Proceeding to install fastfetch..."
        run_script "install_fastfetch.sh" "$GITPATH/installs" "$INSTALLS_URL"
    fi
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
    echo "8) Run DWM Setup Script"
    echo "0) Exit"
    echo

    read -p "Enter your choice (0-8): " choice

    case $choice in
        1) 
            echo "Running Chris Titus Tech's script..."
            curl -fsSL christitus.com/linux | sh
            ;;
        2) run_script "install_ncdu.sh" "$GITPATH/installs" "$INSTALLS_URL" ;;
        3) run_script "cockpit.sh" "$GITPATH/installs" "$INSTALLS_URL" ;;
        4) run_script "add_network_drive.sh" "$GITPATH/installs" "$INSTALLS_URL" ;;
        5) run_script "qemu-guest-agent.sh" "$GITPATH/installs" "$INSTALLS_URL" ;;
        6) 
            echo "Installing Tailscale..."
            curl -fsSL https://tailscale.com/install.sh | sh
            echo "Tailscale installed. Please run 'sudo tailscale up' to activate."
            ;;
        7) run_script "docker.sh" "$GITPATH/installs" "$INSTALLS_URL" ;;
        8)
            echo "Running DWM Setup Script..."
            run_script "dwm_setup.sh" "$GITPATH/installs" "$INSTALLS_URL"
            ;;
        0) echo "Exiting script."; break ;;
        *) echo "Invalid option. Please enter a number between 0 and 8." ;;
    esac
done

echo "#############################"
echo "##                         ##"
echo "## Setup script completed. ##"
echo "##                         ##"
echo "#############################"