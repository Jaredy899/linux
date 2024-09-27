#!/bin/sh -e

# Source the common script from the same directory
. "$(dirname "$0")/common_script.sh"

# Run the environment check
checkEnv || exit 1

# Set the GITPATH variable to the directory where the script is located
GITPATH="$(cd "$(dirname "$0")" && pwd)"
printf "%b\n" "${CYAN}GITPATH is set to: $GITPATH${RC}"

# GitHub URL base for the necessary configuration files
GITHUB_BASE_URL="https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/dev/"
INSTALLS_URL="$GITHUB_BASE_URL/installs"

# Function to run a script from local or GitHub
run_script() {
    script_name="$1"
    local_path="$2"
    url="$3"

    if [ -f "$local_path/$script_name" ]; then
        printf "%b\n" "${YELLOW}Running $script_name from local directory...${RC}"
        sh "$local_path/$script_name"
    else
        printf "%b\n" "${YELLOW}Running $script_name from GitHub...${RC}"
        curl -fsSL "$url/$script_name" -o "/tmp/$script_name"
        sh "/tmp/$script_name"
        rm "/tmp/$script_name"
    fi
}

# Check if running in an Arch Linux ISO environment
if [ -d /run/archiso/bootmnt ]; then
    printf "%b\n" "${CYAN}Arch Linux ISO environment detected.${RC}"
    printf "%b" "${CYAN}Do you want to run the Arch install script? (y/n): ${RC}"
    read -r run_install
    if [ "$run_install" = "y" ] || [ "$run_install" = "Y" ]; then
        run_script "arch_install.sh" "$GITPATH/installs" "$INSTALLS_URL"
    fi
fi

# Ensure git is installed
if ! command_exists git; then
    printf "%b\n" "${YELLOW}Git is not installed. Installing git...${RC}"
    run_script "install_git.sh" "$GITPATH/installs" "$INSTALLS_URL"
else
    printf "%b\n" "${GREEN}Git is already installed.${RC}"
fi

# Menu loop
while true; do
    printf "%b\n" "${CYAN}#############################${RC}"
    printf "%b\n" "${CYAN}##    Select an option:    ##${RC}"
    printf "%b\n" "${CYAN}#############################${RC}"
    printf "%b\n" "${CYAN}1) Run Post Install Script${RC}"
    printf "%b\n" "${CYAN}2) Run Chris Titus Tech Script${RC}"
    printf "%b\n" "${CYAN}3) Add SSH Key${RC}"
    printf "%b\n" "${CYAN}4) Install a network drive${RC}"
    printf "%b\n" "${CYAN}5) Install Cockpit${RC}"
    printf "%b\n" "${CYAN}6) Install Tailscale${RC}"
    printf "%b\n" "${CYAN}7) Install Docker and Portainer${RC}"
    printf "%b\n" "${CYAN}8) Run DWM Setup Script${RC}"
    printf "%b\n" "${CYAN}9) Replace configs${RC}"
    printf "%b\n" "${CYAN}0) Exit${RC}"
    printf "\n"

    printf "%b" "${CYAN}Enter your choice (0-9): ${RC}"
    read -r choice

    case $choice in
        1) 
            printf "%b\n" "${YELLOW}Running Post Install Script...${RC}"
            run_script "post_install.sh" "$GITPATH/installs" "$INSTALLS_URL"
            ;;
        2) 
            printf "%b\n" "${YELLOW}Running Chris Titus Tech's script...${RC}"
            curl -fsSL christitus.com/linuxdev | sh
            ;;
        3) run_script "add_ssh_key.sh" "$GITPATH/installs" "$INSTALLS_URL" ;;
        4) run_script "add_network_drive.sh" "$GITPATH/installs" "$INSTALLS_URL" ;;
        5) 
            printf "%b\n" "${YELLOW}Installing Cockpit...${RC}"
            run_script "cockpit.sh" "$GITPATH/installs" "$INSTALLS_URL"
            ;;
        6) 
            printf "%b\n" "${YELLOW}Installing Tailscale...${RC}"
            curl -fsSL https://tailscale.com/install.sh | sh
            printf "%b\n" "${GREEN}Tailscale installed. Please run 'sudo tailscale up' to activate.${RC}"
            ;;
        7) run_script "docker.sh" "$GITPATH/installs" "$INSTALLS_URL" ;;
        8) 
            printf "%b\n" "${YELLOW}Running DWM Setup Script...${RC}"
            run_script "install_dwm.sh" "$GITPATH/installs" "$INSTALLS_URL"
            ;;
        9)
            printf "%b\n" "${YELLOW}Replacing configs...${RC}"
            run_script "replace_configs.sh" "$GITPATH/installs" "$INSTALLS_URL"
            ;;
        0) printf "%b\n" "${GREEN}Exiting script.${RC}"; break ;;
        *) printf "%b\n" "${RED}Invalid option. Please enter a number between 0 and 9.${RC}" ;;
    esac
done

printf "%b\n" "${GREEN}#############################${RC}"
printf "%b\n" "${GREEN}##                         ##${RC}"
printf "%b\n" "${GREEN}## Setup script completed. ##${RC}"
printf "%b\n" "${GREEN}##                         ##${RC}"
printf "%b\n" "${GREEN}#############################${RC}"