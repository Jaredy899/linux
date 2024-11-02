#!/bin/sh -e

# Source the common script
. <(curl -s https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/common_script.sh)

# Function to install desktop environment on Arch
install_arch_de() {
    case $1 in
        1) noninteractive cinnamon sddm xorg-server feh ;;
        2) noninteractive plasma plasma-wayland-protocols plasma-desktop sddm plasma-pa plasma-nm thunar xorg-server feh ;;
        3) run_script "install_dwm.sh" "$GITPATH/installs" "$INSTALLS_URL" ;;
    esac
}

# Function to install desktop environment on Fedora
install_fedora_de() {
    case $1 in
        1) noninteractive @"Cinnamon Desktop" sddm feh ;;
        2) noninteractive @"KDE Plasma Workspaces" feh ;;
        3) noninteractive run_script "install_dwm.sh" "$GITPATH/installs" "$INSTALLS_URL" ;;
    esac
}

# Function to install desktop environment on Debian/Ubuntu
install_debian_de() {
    case $1 in
        1) noninteractive cinnamon lightdm feh ;;
        2) noninteractive kde-plasma-desktop lightdm plasma-workspace thunar konsole feh ;;
        3) noninteractive run_script "install_dwm.sh" "$GITPATH/installs" "$INSTALLS_URL" ;;
    esac
}

# Main script
clear
printf "%b\n" "${BLUE}Desktop Environment Installer${RC}"
echo "------------------------"

# Check environment and requirements
if ! checkEnv; then
    printf "%b\n" "${RED}Environment check failed. Please fix the issues above.${RC}"
    exit 1
fi

printf "%b\n" "${CYAN}Detected Distribution: $DTYPE${RC}"
echo -e "\nAvailable Desktop Environments:"
echo "1. Cinnamon"
echo "2. KDE Plasma"
echo "3. DWM"
printf "%b" "${YELLOW}Select your desired desktop environment (1-3): ${RC}"
read -r choice

if [ "$choice" -ge 1 ] && [ "$choice" -le 3 ]; then
    # Update system first
    case $PACKAGER in
        pacman) $ESCALATION_TOOL $PACKAGER -Syu $(getNonInteractiveFlags) ;;
        apt-get|nala) 
            $ESCALATION_TOOL $PACKAGER update
            $ESCALATION_TOOL $PACKAGER upgrade $(getNonInteractiveFlags)
            ;;
        dnf) $ESCALATION_TOOL $PACKAGER update $(getNonInteractiveFlags) ;;
    esac

    # Install selected desktop environment
    case $DTYPE in
        "arch") install_arch_de "$choice" ;;
        "fedora") install_fedora_de "$choice" ;;
        "debian"|"ubuntu") install_debian_de "$choice" ;;
        *)
            printf "%b\n" "${RED}Unsupported distribution: $DTYPE${RC}"
            exit 1
            ;;
    esac

    # Enable display manager
    case $DTYPE in
        "arch"|"fedora")
            case $choice in
                1|2) $ESCALATION_TOOL systemctl enable sddm ;;
                3) : ;; # DWM handles its own display manager setup
            esac
            ;;
        "debian"|"ubuntu")
            case $choice in
                1|2) $ESCALATION_TOOL systemctl enable lightdm ;;
                3) : ;; # DWM handles its own display manager setup
            esac
            ;;
    esac

    # Setup wallpapers
    mkdir -p "$HOME/Pictures"
    cd "$HOME/Pictures" || exit
    if [ ! -d "nord-background" ]; then
        git clone https://github.com/ChrisTitusTech/nord-background.git
    fi
    feh --bg-scale --randomize "$HOME/Pictures/nord-background/"

    printf "%b\n" "${GREEN}Installation complete! Please reboot your system.${RC}"
else
    printf "%b\n" "${RED}Invalid choice. Please select a number between 1 and 3.${RC}"
    exit 1
fi 