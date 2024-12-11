#!/bin/sh

set -e  # Exit immediately if a command exits with a non-zero status
IFS='
	'

# Define color variables
RC='\033[0m'
RED='\033[31m'
YELLOW='\033[33m'
CYAN='\033[36m'
GREEN='\033[32m'

# Set the GITPATH variable to the directory where the script is located
if [ -f "$0" ]; then
    GITPATH=$(cd "$(dirname "$0")" && pwd)
else
    GITPATH="$HOME"
fi
printf "${CYAN}GITPATH is set to: %s${RC}\n" "$GITPATH"

# GitHub URL base for the necessary configuration files
GITHUB_BASE_URL="https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/"
INSTALLS_URL="${GITHUB_BASE_URL}/installs"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to detect the Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        printf "%s\n" "$ID"
    else
        printf "unknown\n"
    fi
}

# Detect the Linux distribution
distro=$(detect_distro)
if [ "$distro" = "unknown" ]; then
    printf "${RED}Unable to detect Linux distribution. Exiting.${RC}\n"
    exit 1
fi

# Function to run a script from local or GitHub
run_script() {
    script_name="$1"
    local_path="$2"
    url="$3"

    if [ -f "$local_path/$script_name" ]; then
        printf "${YELLOW}Running %s from local directory...${RC}\n" "$script_name"
        sh "$local_path/$script_name"
    else
        printf "${YELLOW}Running %s from GitHub...${RC}\n" "$script_name"
        curl -fsSL "$url/$script_name" -o "/tmp/$script_name"
        sh "/tmp/$script_name"
        rm "/tmp/$script_name"
    fi
}

# Check if running in an Arch Linux ISO environment
if [ -d /run/archiso/bootmnt ]; then
    printf "${YELLOW}Arch Linux ISO environment detected.${RC}\n"
    printf "Do you want to run the Arch install script? (y/n): "
    read run_install
    if [ "$run_install" = "y" ] || [ "$run_install" = "Y" ]; then
        run_script "arch_install2.sh" "$GITPATH/installs" "$INSTALLS_URL"
    fi
fi

# Ensure git is installed
if ! command_exists git; then
    printf "${RED}Git is not installed. Installing git...${RC}\n"
    run_script "install_git.sh" "$GITPATH/installs" "$INSTALLS_URL"
else
    printf "${GREEN}Git is already installed.${RC}\n"
fi

# Menu loop
while true; do
    printf "${CYAN}#############################${RC}\n"
    printf "${CYAN}##    Select an option:    ##${RC}\n"
    printf "${CYAN}#############################${RC}\n"
    printf "1) Run Post Install Script\n"
    printf "2) Run Chris Titus Tech Script\n"
    printf "3) Add SSH Key\n"
    printf "4) Install a network drive\n"
    printf "5) Install Cockpit\n"
    printf "6) Install Tailscale\n"
    printf "7) Install Docker\n"
    printf "8) Install Desktop Environment\n"
    printf "9) Replace configs\n"
    printf "0) Exit\n\n"

    printf "Enter your choice (0-9): "
    read choice

    case $choice in
        1) 
            printf "${YELLOW}Running Post Install Script...${RC}\n"
            run_script "post_install.sh" "$GITPATH/installs" "$INSTALLS_URL"
            ;;
        2) 
            printf "${YELLOW}Running Chris Titus Tech's script...${RC}\n"
            curl -fsSL christitus.com/linuxdev | sh
            ;;
        3) run_script "add_ssh_key.sh" "$GITPATH/installs" "$INSTALLS_URL" ;;
        4) run_script "add_network_drive.sh" "$GITPATH/installs" "$INSTALLS_URL" ;;
        5) 
            printf "${YELLOW}Installing Cockpit...${RC}\n"
            run_script "cockpit.sh" "$GITPATH/installs" "$INSTALLS_URL"
            ;;
        6) 
            printf "${YELLOW}Installing Tailscale...${RC}\n"
            curl -fsSL https://tailscale.com/install.sh | sh
            printf "${GREEN}Tailscale installed. Please run 'sudo tailscale up' to activate.${RC}\n"
            ;;
        7) run_script "docker.sh" "$GITPATH/installs" "$INSTALLS_URL" ;;
        8)
            printf "${YELLOW}Installing Desktop Environment...${RC}\n"
            run_script "de-installer.sh" "$GITPATH/installs" "$INSTALLS_URL"
            ;;
        9)
            printf "${YELLOW}Replacing configs...${RC}\n"
            run_script "replace_configs.sh" "$GITPATH/installs" "$INSTALLS_URL"
            ;;
        0) printf "${GREEN}Exiting script.${RC}\n"; break ;;
        *) printf "${RED}Invalid option. Please enter a number between 0 and 9.${RC}\n" ;;
    esac
done

printf "${GREEN}#############################${RC}\n"
printf "${GREEN}##                         ##${RC}\n"
printf "${GREEN}## Setup script completed. ##${RC}\n"
printf "${GREEN}##                         ##${RC}\n"
printf "${GREEN}#############################${RC}\n"
