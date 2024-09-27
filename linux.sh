#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status
IFS=$'\n\t'

# Create a temporary directory
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Debug: Print current directory and script location
echo "Current directory: $(pwd)"
echo "Temporary directory: $TEMP_DIR"

# Download the common script to the temporary directory
COMMON_SCRIPT_URL="https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/dev/common_script.sh"
if curl -fsSL "$COMMON_SCRIPT_URL" > "$TEMP_DIR/common_script.sh"; then
    echo "common_script.sh downloaded successfully"
    . "$TEMP_DIR/common_script.sh"
else
    echo "Failed to download common_script.sh"
    exit 1
fi

echo "common_script.sh sourced successfully"

# Debug: Check if required functions are available
if ! command -v checkEnv > /dev/null 2>&1; then
    echo "checkEnv function not found"
    exit 1
fi

# Run the environment check
if ! checkEnv; then
    echo "Environment check failed"
    exit 1
fi

# GitHub URL base for the necessary configuration files
GITHUB_BASE_URL="https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/dev/"
INSTALLS_URL="$GITHUB_BASE_URL/installs"

# Function to run a script from GitHub
run_script() {
    local script_name="$1"
    local url="$2"

    echo "Running $script_name from GitHub..."
    curl -fsSL "$url/$script_name" | bash
}

# Check if running in an Arch Linux ISO environment
if [ -d /run/archiso/bootmnt ]; then
    printf "%b\n" "${YELLOW}Arch Linux ISO environment detected.${RC}"
    printf "%b" "${CYAN}Do you want to run the Arch install script? (y/n): ${RC}"
    read -r run_install
    if [[ "$run_install" =~ ^[Yy]$ ]]; then
        run_script "arch_install.sh" "$INSTALLS_URL"
    fi
fi

# Ensure git is installed
if ! command_exists git; then
    printf "%b\n" "${YELLOW}Git is not installed. Installing git...${RC}"
    run_script "install_git.sh" "$INSTALLS_URL"
else
    printf "%b\n" "${GREEN}Git is already installed.${RC}"
fi

# Menu loop
while true; do
    printf "%b\n" "${CYAN}#############################"
    printf "%b\n" "##    Select an option:    ##"
    printf "%b\n" "#############################${RC}"
    printf "%b\n" "1) Run Post Install Script"
    printf "%b\n" "2) Run Chris Titus Tech Script"
    printf "%b\n" "3) Add SSH Key"
    printf "%b\n" "4) Install a network drive"
    printf "%b\n" "5) Install Cockpit"
    printf "%b\n" "6) Install Tailscale"
    printf "%b\n" "7) Install Docker and Portainer"
    printf "%b\n" "8) Run DWM Setup Script"
    printf "%b\n" "9) Replace configs"
    printf "%b\n" "0) Exit"
    echo

    printf "%b" "${CYAN}Enter your choice (0-9): ${RC}"
    read -r choice

    case $choice in
        1) 
            printf "%b\n" "${YELLOW}Running Post Install Script...${RC}"
            run_script "post_install.sh" "$INSTALLS_URL"
            ;;
        2) 
            printf "%b\n" "${YELLOW}Running Chris Titus Tech's script...${RC}"
            curl -fsSL christitus.com/linuxdev | sh
            ;;
        3) run_script "add_ssh_key.sh" "$INSTALLS_URL" ;;
        4) run_script "add_network_drive.sh" "$INSTALLS_URL" ;;
        5) 
            printf "%b\n" "${YELLOW}Installing Cockpit...${RC}"
            run_script "cockpit.sh" "$INSTALLS_URL"
            ;;
        6) 
            printf "%b\n" "${YELLOW}Installing Tailscale...${RC}"
            curl -fsSL https://tailscale.com/install.sh | sh
            printf "%b\n" "${GREEN}Tailscale installed. Please run 'sudo tailscale up' to activate.${RC}"
            ;;
        7) run_script "docker.sh" "$INSTALLS_URL" ;;
        8) 
            printf "%b\n" "${YELLOW}Running DWM Setup Script...${RC}"
            run_script "install_dwm.sh" "$INSTALLS_URL"
            ;;
        9)
            printf "%b\n" "${YELLOW}Replacing configs...${RC}"
            run_script "replace_configs.sh" "$INSTALLS_URL"
            ;;
        0) printf "%b\n" "${GREEN}Exiting script.${RC}"; break ;;
        *) printf "%b\n" "${RED}Invalid option. Please enter a number between 0 and 9.${RC}" ;;
    esac
done

printf "%b\n" "${GREEN}#############################"
printf "%b\n" "##                         ##"
printf "%b\n" "## Setup script completed. ##"
printf "%b\n" "##                         ##"
printf "%b\n" "#############################${RC}"