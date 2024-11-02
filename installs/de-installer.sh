#!/bin/sh -e

# Source the common script
. <(curl -s https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/common_script.sh)

# Function to install desktop environment on Arch
install_arch_de() {
    case $1 in
        1) noninteractive cinnamon lightdm lightdm-gtk-greeter ;;
        2) noninteractive plasma plasma-wayland-protocols plasma-desktop sddm plasma-pa plasma-nm konsole dolphin ;;
        3) noninteractive gnome gnome-extra gdm ;;
        4) noninteractive i3-gaps i3status i3blocks dmenu lightdm lightdm-gtk-greeter ;;
    esac
}

# Function to install desktop environment on Fedora
install_fedora_de() {
    case $1 in
        1) noninteractive @"Cinnamon Desktop" ;;
        2) noninteractive @"KDE Plasma Workspaces" ;;
        3) noninteractive @"GNOME Desktop Environment" ;;
        4) noninteractive i3 i3status dmenu lightdm ;;
    esac
}

# Function to install desktop environment on Debian/Ubuntu
install_debian_de() {
    case $1 in
        1) noninteractive cinnamon lightdm ;;
        2) noninteractive kde-plasma-desktop sddm ;;
        3) noninteractive gnome gnome-shell gdm3 ;;
        4) noninteractive i3 i3status dmenu lightdm ;;
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
echo "3. GNOME"
echo "4. i3"
printf "%b" "${YELLOW}Select your desired desktop environment (1-4): ${RC}"
read -r choice

if [ "$choice" -ge 1 ] && [ "$choice" -le 4 ]; then
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
    case $choice in
        1|4) $ESCALATION_TOOL systemctl enable lightdm ;;
        2) $ESCALATION_TOOL systemctl enable sddm ;;
        3) 
            if [ "$DTYPE" = "debian" ] || [ "$DTYPE" = "ubuntu" ]; then
                $ESCALATION_TOOL systemctl enable gdm3
            else
                $ESCALATION_TOOL systemctl enable gdm
            fi
            ;;
    esac

    printf "%b\n" "${GREEN}Installation complete! Please reboot your system.${RC}"
else
    printf "%b\n" "${RED}Invalid choice. Please select a number between 1 and 4.${RC}"
    exit 1
fi 