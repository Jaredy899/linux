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
        1) 
            # Install Cinnamon
            noninteractive cinnamon dolphin konsole lightdm xed xreader feh
            ;;
        2) 
            # Install KDE Plasma
            noninteractive plasma-meta sddm dolphin konsole feh
            ;;
        3) 
            # Install DWM
            install_dwm
            ;;
        4) 
            # Install COSMIC
            noninteractive cosmic
            ;;
    esac
}

# Function to install desktop environment on Fedora
install_fedora_de() {
    case $1 in
        1) 
            # Install Cinnamon
            noninteractive @"cinnamon-desktop" lightdm feh
            ;;
        2) 
            # Install KDE Plasma
            $ESCALATION_TOOL $PACKAGER remove -y sddm-wayland-generic
            noninteractive @"kde-desktop-environment" sddm feh
            ;;
        3) 
            # Install DWM
            install_dwm
            ;;
        4) 
            # Install COSMIC
            noninteractive @"cosmic-desktop-environment"
            ;;
    esac
}

# Function to install desktop environment on Debian/Ubuntu
install_debian_de() {
    case $1 in
        1) 
            # Install Cinnamon
            noninteractive cinnamon-core lightdm feh
            ;;
        2) 
            # Install KDE Plasma
            echo "sddm shared/default-display-manager select sddm" | $ESCALATION_TOOL debconf-set-selections
            noninteractive kde-plasma-desktop plasma-desktop plasma-workspace sddm plasma-nm plasma-pa dolphin konsole kwin-x11 systemsettings plasma-workspace-wayland feh
            ;;
        3) 
            # Install DWM
            install_dwm 
            ;;
    esac
}

# Update function for openSUSE (both Leap and Tumbleweed)
install_opensuse_de() {
    case $1 in
        1) 
            # Install Cinnamon
            noninteractive -t pattern cinnamon
            noninteractive lightdm
            ;;
        2) 
            # Install KDE Plasma
            $ESCALATION_TOOL sed -i 's/^DISPLAYMANAGER=.*/DISPLAYMANAGER="sddm"/' /etc/sysconfig/displaymanager
            ;;
        3) 
            # Install DWM
            install_dwm
            return
            ;;
        4) 
            # Install COSMIC
            # Auto-accept repository key
            echo "a" | $ESCALATION_TOOL zypper --non-interactive addrepo https://download.opensuse.org/repositories/X11:/COSMIC:/Factory/openSUSE_Factory/ X11:COSMIC:Factory
            echo "a" | $ESCALATION_TOOL zypper --non-interactive refresh
            $ESCALATION_TOOL zypper --non-interactive install -t pattern patterns-cosmic-cosmic
            $ESCALATION_TOOL sed -i 's/^DISPLAYMANAGER=.*/DISPLAYMANAGER="gdm"/' /etc/sysconfig/displaymanager
            ;;
    esac
    
    $ESCALATION_TOOL systemctl set-default graphical.target
}

# Function to detect the current display manager
get_current_dm() {
    if [ -f /etc/systemd/system/display-manager.service ]; then
        basename "$(readlink /etc/systemd/system/display-manager.service)" .service
    else
        echo ""
    fi
}

# Function to enable the display manager
enable_display_manager() {
    local dm=$1
    case $DTYPE in
        "arch"|"fedora"|"debian"|"ubuntu")
            enableService "$dm"
            ;;
        "opensuse"|"opensuse-tumbleweed"|"opensuse-leap")
            $ESCALATION_TOOL sed -i "s/^DISPLAYMANAGER=.*/DISPLAYMANAGER=\"$dm\"/" /etc/sysconfig/displaymanager
            enableService "$dm"
            ;;
    esac
}

# Function to update the system
update_system() {
    case $PACKAGER in
        pacman) $ESCALATION_TOOL $PACKAGER -Syu $(getNonInteractiveFlags) ;;
        apt-get|nala) 
            $ESCALATION_TOOL $PACKAGER update
            $ESCALATION_TOOL $PACKAGER upgrade $(getNonInteractiveFlags)
            ;;
        dnf) $ESCALATION_TOOL $PACKAGER update $(getNonInteractiveFlags) ;;
    esac
}

# Function to display menu items
show_de_menu() {
    show_menu_item 1 "${NC}" "Cinnamon"
    show_menu_item 2 "${NC}" "KDE Plasma"
    show_menu_item 3 "${NC}" "DWM"
    show_menu_item 4 "${NC}" "Cosmic"
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

# Detect current display manager
current_dm=$(get_current_dm)
if [ -n "$current_dm" ]; then
    printf "%b\n" "${CYAN}Detected existing display manager: $current_dm${RC}"
else
    printf "%b\n" "${CYAN}No existing display manager detected.${RC}"
fi

printf "%b\n" "${CYAN}Detected Distribution: $DTYPE${RC}"
printf "\nAvailable Desktop Environments:\n"

# Use arrow keys to select the desktop environment
handle_menu_selection 4 "Select your desired desktop environment:" show_de_menu
choice=$?

if [ "$choice" -ge 1 ] && [ "$choice" -le 4 ]; then
    # Update system first
    update_system

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

    # Enable display manager if not already set
    if [ -z "$current_dm" ]; then
        case $choice in
            1|2) enable_display_manager "sddm" ;;
            3) : ;; # DWM handles its own display manager setup
            4) enable_display_manager "gdm" ;; # Enable GDM for COSMIC
        esac
    else
        printf "%b\n" "${CYAN}Using existing display manager: $current_dm${RC}"
    fi

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
