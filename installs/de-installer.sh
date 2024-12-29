#!/bin/sh -e

# Source the common script
eval "$(curl -s https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/common_script.sh)"
eval "$(curl -s https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/common_service_script.sh)"

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
        1) noninteractive cinnamon dolphin konsole sddm xed xreader feh ;;
        2) noninteractive plasma-meta sddm dolphin konsole feh ;;
        3) install_dwm ;;
    esac
}

# Function to install desktop environment on Fedora
install_fedora_de() {
    case $1 in
        1) 
            noninteractive @"cinnamon-desktop" sddm-wayland-generic feh
            $ESCALATION_TOOL systemctl set-default graphical.target ;;
        2) 
            # Remove generic SDDM if installed
            $ESCALATION_TOOL $PACKAGER remove -y sddm-wayland-generic
            noninteractive @"kde-desktop-environment" sddm feh
            $ESCALATION_TOOL systemctl set-default graphical.target ;;
        3) install_dwm ;;
    esac
}

# Function to install desktop environment on Debian/Ubuntu
install_debian_de() {
    case $1 in
        1) 
            # Pre-configure SDDM to avoid prompts
            echo "sddm shared/default-display-manager select sddm" | $ESCALATION_TOOL debconf-set-selections
            noninteractive cinnamon-core sddm feh ;;
        2) 
            # Pre-configure SDDM to avoid prompts
            echo "sddm shared/default-display-manager select sddm" | $ESCALATION_TOOL debconf-set-selections
            noninteractive kde-plasma-desktop plasma-desktop plasma-workspace sddm plasma-nm plasma-pa dolphin konsole kwin-x11 systemsettings plasma-workspace-wayland feh ;;
        3) install_dwm ;;
    esac
}

# Update function for openSUSE (both Leap and Tumbleweed)
install_opensuse_de() {
    case $1 in
        1) 
            noninteractive -t pattern cinnamon
            noninteractive sddm ;;
        2) 
            noninteractive -t pattern kde kde_plasma
            $ESCALATION_TOOL sed -i 's/^DISPLAYMANAGER=.*/DISPLAYMANAGER="sddm"/' /etc/sysconfig/displaymanager ;;
        3) install_dwm
           return ;;
    esac
    
    $ESCALATION_TOOL systemctl set-default graphical.target
}

# Function to install COSMIC on supported distributions
install_cosmic() {
    case $DTYPE in
        "arch")
            # Instructions for Arch Linux
            noninteractive cosmic
            ;;
        "fedora")
            # Instructions for Fedora
            noninteractive @"cosmic-desktop-environment"
            ;;
        "opensuse"|"opensuse-tumbleweed"|"opensuse-leap")
            # Instructions for openSUSE
            $ESCALATION_TOOL zypper --non-interactive addrepo https://download.opensuse.org/repositories/X11:/COSMIC:/Factory/openSUSE_Factory/ X11:COSMIC:Factory
            $ESCALATION_TOOL zypper --non-interactive refresh
            $ESCALATION_TOOL zypper --non-interactive install -t pattern patterns-cosmic-cosmic
            ;;
        *)
            printf "%b\n" "${RED}COSMIC is not supported on this distribution: $DTYPE${RC}"
            exit 1
            ;;
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
printf "\nAvailable Desktop Environments:\n"
echo "1. Cinnamon"
echo "2. KDE Plasma"
echo "3. DWM"
echo "4. COSMIC"
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
        "opensuse"|"opensuse-tumbleweed"|"opensuse-leap") install_opensuse_de "$choice" ;;
        *)
            printf "%b\n" "${RED}Unsupported distribution: $DTYPE${RC}"
            exit 1
            ;;
    esac

    # Enable display manager
    case $DTYPE in
        "arch"|"fedora"|"debian"|"ubuntu")
            case $choice in
                1|2) $ESCALATION_TOOL systemctl enable sddm ;;
                3) : ;; # DWM handles its own display manager setup
            esac
            ;;
        "opensuse"|"opensuse-tumbleweed"|"opensuse-leap")
            case $choice in
                1|2)
                    # Configure and enable SDDM for openSUSE
                    $ESCALATION_TOOL sed -i 's/^DISPLAYMANAGER=.*/DISPLAYMANAGER="sddm"/' /etc/sysconfig/displaymanager
                    $ESCALATION_TOOL systemctl enable sddm
                    ;;
                3) : ;; # DWM handles its own display manager setup
            esac
            ;;
    esac

    # Setup wallpapers
    mkdir -p "$HOME/Pictures"
    cd "$HOME/Pictures" || exit
    git clone https://github.com/ChrisTitusTech/nord-background.git
    echo 'feh --bg-scale --randomize "$HOME/Pictures/nord-background/"' >> "$HOME/.xinitrc"

    printf "%b\n" "${GREEN}Installation complete! Please reboot your system.${RC}"
else
    printf "%b\n" "${RED}Invalid choice. Please select a number between 1 and 4.${RC}"
    exit 1
fi 
