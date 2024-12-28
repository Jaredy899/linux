#!/bin/sh

IFS='
	'

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

# Only source common_script.sh (which contains the menu system) after the arch install check
eval "$(curl -s https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/common_script.sh)"

# Ensure git is installed
if ! command_exists git; then
    printf "${RED}Git is not installed. Installing git...${RC}\n"
    run_script "install_git.sh" "$GITPATH/installs" "$INSTALLS_URL"
else
    printf "${GREEN}Git is already installed.${RC}\n"
fi

# Function to display main menu items
show_main_menu() {
    show_menu_item 1  "${NC}" "Run Post Install Script"
    show_menu_item 2  "${NC}" "Run Chris Titus Tech Script"
    show_menu_item 3  "${NC}" "Add SSH Key"
    show_menu_item 4  "${NC}" "Install a network drive"
    show_menu_item 5  "${NC}" "Install Cockpit"
    show_menu_item 6  "${NC}" "Install Tailscale"
    show_menu_item 7  "${NC}" "Install Docker"
    show_menu_item 8  "${NC}" "Update System"
    show_menu_item 9  "${NC}" "Replace configs"
    show_menu_item 10 "${NC}" "Install Desktop Environment"
    show_menu_item 11 "${NC}" "Install NetworkManager"
    show_menu_item 12 "${NC}" "Exit"
}

while true; do
    handle_menu_selection 12 "Select an option:" show_main_menu
    choice=$?
    
    case $choice in
        1)
            run_script "post_install.sh" "$GITPATH/installs" "$INSTALLS_URL"
            ;;
        2)
            curl -fsSL https://github.com/Jaredy899/jaredlinutil/releases/download/v1.0/start.sh | sh
            ;;
        3)
            run_script "add_ssh_key.sh" "$GITPATH/installs" "$INSTALLS_URL"
            ;;
        4)
            run_script "add_network_drive.sh" "$GITPATH/installs" "$INSTALLS_URL"
            ;;
        5)
            run_script "cockpit.sh" "$GITPATH/installs" "$INSTALLS_URL"
            ;;
        6)
            curl -fsSL https://tailscale.com/install.sh | sh
            ;;
        7)
            run_script "docker.sh" "$GITPATH/installs" "$INSTALLS_URL"
            ;;
        8)
            run_script "updater.sh" "$GITPATH/installs" "$INSTALLS_URL"
            ;;
        9)
            run_script "replace_configs.sh" "$GITPATH/installs" "$INSTALLS_URL"
            ;;
        10)
            run_script "de-installer.sh" "$GITPATH/installs" "$INSTALLS_URL"
            ;;
        11)
            run_script "install_networkmanager.sh" "$GITPATH/installs" "$INSTALLS_URL"
            ;;
        12)
            printf "${GREEN}Exiting script.${RC}\n"
            exit 0
            ;;
    esac
    
    printf "\nPress any key to continue..."
    saved_tty_settings=$(stty -g)   # Save current terminal settings
    stty raw -echo                  # Change terminal settings
    dd bs=1 count=1 2>/dev/null     # Read one character
    stty "$saved_tty_settings"      # Restore terminal settings
    printf "\n"
    clear
done
