#!/bin/bash

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

# Main logic to check the distribution and install fastfetch
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "$ID" = "debian" ] || [ "$ID" = "ubuntu" ]; then
        echo "Detected $ID system. Proceeding with fastfetch installation."
        install_fastfetch
    else
        echo "This script is intended for Debian-based systems only (Debian/Ubuntu). Exiting."
        exit 1
    fi
else
    echo "Cannot detect the operating system. /etc/os-release not found. Exiting."
    exit 1
fi

# Menu loop
while true; do
    echo "#############################"
    echo "##    Select an option:    ##"
    echo "#############################"
    echo "1) Run ChrisTitusTech script"
    echo "2) Fix .bashrc"
    echo "3) Replace Fastfetch with Jared's custom one"
    echo "4) Replace Starship with Jared's custom one"
    echo "5) Install ncdu"
    echo "6) Install Cockpit"
    echo "7) Install a network drive"
    echo "8) Install qemu-guest-agent"
    echo "9) Install Tailscale"
    echo "10) Install Docker and Portainer"
    echo "0) Exit"
    echo

    read -p "Enter your choice (0-10): " choice

    case $choice in
        1) run_script "ChrisTitusTech.sh" "$GITPATH" "curl -fsSL christitus.com/linux |sh" ;;
        2) run_script "fix_bashrc.sh" "$GITPATH" "$GITHUB_BASE_URL" ;;
        3) run_script "replace_config_jsonc.sh" "$GITPATH" "$GITHUB_BASE_URL" ;;
        4) run_script "replace_starship_toml.sh" "$GITPATH" "$GITHUB_BASE_URL" ;;
        5) run_script "install_ncdu.sh" "$GITPATH" "$GITHUB_BASE_URL" ;;
        6) run_script "cockpit.sh" "$GITPATH" "$GITHUB_BASE_URL" ;;
        7) run_script "add_network_drive.sh" "$GITPATH" "$GITHUB_BASE_URL" ;;
        8) run_script "qemu-guest-agent.sh" "$GITPATH" "$GITHUB_BASE_URL" ;;
        9) run_script "tailscale_install.sh" "$GITPATH" "curl -fsSL https://tailscale.com/install.sh | sh" ;;
        10) run_script "docker.sh" "$GITPATH" "$GITHUB_BASE_URL" ;;
        0) echo "Exiting script."; break ;;
        *) echo "Invalid option. Please enter a number between 0 and 10." ;;
    esac
done

echo "#############################"
echo "##                         ##"
echo "## Setup script completed. ##"
echo "##                         ##"
echo "#############################"
