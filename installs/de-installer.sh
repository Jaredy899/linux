#!/bin/sh -e

# Source the common script
. <(curl -s https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/common_script.sh)

# Common DWM installation function
install_dwm() {
    DWM_SCRIPT_URL="https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/installs/install_dwm.sh"
    if ! curl -s "$DWM_SCRIPT_URL" -o /tmp/install_dwm.sh; then
        echo "Failed to download DWM install script"
        exit 1
    fi
    chmod +x /tmp/install_dwm.sh
    /tmp/install_dwm.sh
}

# Function to install desktop environment on Arch
install_arch_de() {
    case $1 in
        1) noninteractive cinnamon sddm xorg-server feh ;;
        2) noninteractive plasma plasma-wayland-protocols plasma-desktop sddm plasma-pa plasma-nm thunar konsole xorg-server feh ;;
        3) install_dwm ;;
    esac
}

# Function to install desktop environment on Fedora
install_fedora_de() {
    case $1 in
        1) noninteractive @"Cinnamon Desktop" sddm feh ;;
        2) noninteractive @"KDE Plasma Workspaces" feh ;;
        3) install_dwm ;;
    esac
}

# Function to install desktop environment on Debian/Ubuntu
install_debian_de() {
    case $1 in
        1) noninteractive cinnamon lightdm feh ;;
        2) noninteractive kde-plasma-desktop sddm plasma-workspace thunar konsole feh ;;
        3) install_dwm ;;
    esac
}

# Update function for openSUSE (both Leap and Tumbleweed)
install_opensuse_de() {
    # Common packages between Leap and Tumbleweed
    local base_packages
    case $1 in
        1) base_packages="patterns-desktop-cinnamon sddm xorg-x11-server feh" ;;
        2) base_packages="patterns-desktop-plasma plasma-desktop plasma-systemmonitor plasma-nm plasma-pa sddm konsole dolphin feh" ;;
        3) install_dwm
           return ;;
    esac

    # Install feh first to avoid the command not found error
    noninteractive feh
    noninteractive $base_packages
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
        "opensuse"|"opensuse-tumbleweed"|"opensuse-leap") install_opensuse_de "$choice" ;;
        *)
            printf "%b\n" "${RED}Unsupported distribution: $DTYPE${RC}"
            exit 1
            ;;
    esac

    # Enable display manager
    case $DTYPE in
        "arch"|"fedora"|"opensuse")
            case $choice in
                1|2) $ESCALATION_TOOL systemctl enable sddm ;;
                3) : ;; # DWM handles its own display manager setup
            esac
            ;;
        "debian"|"ubuntu")
            case $choice in
                1) $ESCALATION_TOOL systemctl enable lightdm ;;
                2) $ESCALATION_TOOL systemctl enable sddm ;;
                3) : ;; # DWM handles its own display manager setup
            esac
            ;;
    esac

    # Setup wallpapers (create script to run after first login)
    mkdir -p "$HOME/.config/autostart"
    cat > "$HOME/.config/autostart/wallpaper-setup.desktop" << 'EOF'
    [Desktop Entry]
    Type=Application
    Name=Wallpaper Setup
    Exec=bash -c 'mkdir -p "$HOME/Pictures" && cd "$HOME/Pictures" && [ ! -d "nord-background" ] && git clone https://github.com/ChrisTitusTech/nord-background.git; feh --bg-scale --randomize "$HOME/Pictures/nord-background/"'
    Hidden=false
    X-GNOME-Autostart-enabled=true
    EOF

    chmod +x "$HOME/.config/autostart/wallpaper-setup.desktop"

    printf "%b\n" "${GREEN}Installation complete! Please reboot your system.${RC}"
else
    printf "%b\n" "${RED}Invalid choice. Please select a number between 1 and 3.${RC}"
    exit 1
fi 