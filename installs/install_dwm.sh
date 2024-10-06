#!/bin/sh -e

# Source the common script directly from GitHub
. <(curl -s https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/common_script.sh)

# Run the environment check
checkEnv || exit 1

# Ask about autologin at the beginning
printf "%b" "${CYAN}Do you want to set up autologin? (y/n): ${RC}"
read -r setup_autologin

# Function to install a package
installPackage() {
    package_name="$1"
    if ! command_exists "$package_name"; then
        printf "%b\n" "${YELLOW}Installing $package_name...${RC}"
        noninteractive "$package_name"
    else
        printf "%b\n" "${GREEN}$package_name is already installed.${RC}"
    fi
}

# List of common packages to install
common_packages="nano thunar vlc feh pavucontrol pipewire pipewire-alsa alacritty unzip flameshot lxappearance mate-polkit"

# Install common packages
printf "%b\n" "${YELLOW}Installing common packages...${RC}"
for package in $common_packages; do
    installPackage "$package"
done

printf "%b\n" "${GREEN}Common package installation complete.${RC}"

# Install distribution-specific packages
case "$PACKAGER" in
    pacman)
        packages="$common_packages --needed pipewire-audio-client-libraries pipewire-pulse"
        noninteractive $packages
        ;;
    nala)
        packages="$common_packages pipewire-audio-client-libraries pipewire-pulse"
        noninteractive $packages
        ;;
    dnf)
        packages="$common_packages network-manager-applet"
        noninteractive $packages
        ;;
    zypper)
        packages="$common_packages NetworkManager-applet pipewire-pulseaudio"
        noninteractive $packages
        ;;
    *)
        printf "%b\n" "${RED}Unsupported package manager: $PACKAGER${RC}"
        exit 1
        ;;
esac

# Create or update the .xprofile file to autostart nm-applet for all distros
if [ ! -f "$HOME/.xprofile" ]; then
    printf "%b\n" "${YELLOW}Creating .xprofile and adding nm-applet autostart...${RC}"
    echo "nm-applet &" > "$HOME/.xprofile"
else
    if ! grep -q "nm-applet &" "$HOME/.xprofile"; then
        printf "%b\n" "${YELLOW}Adding nm-applet autostart to existing .xprofile...${RC}"
        echo "nm-applet &" >> "$HOME/.xprofile"
    fi
fi

makeDWM() {
    cd "$HOME" && git clone https://github.com/ChrisTitusTech/dwm-titus.git
    cd dwm-titus/
    $ESCALATION_TOOL make clean install
    
    # Install slstatus
    cd slstatus/
    $ESCALATION_TOOL make clean install
    cd ..  # Return to the dwm-titus directory
}

setupDWM() {
    printf "%b\n" "${YELLOW}Installing DWM-Titus if not already installed${RC}"
    case "$PACKAGER" in
        pacman)
            $ESCALATION_TOOL pacman -S --needed --noconfirm xorg-xinit xorg-server base-devel libx11 libxinerama libxft imlib2 libxcb meson libev uthash libconfig
            ;;
        apt|nala)
            $ESCALATION_TOOL apt-get install -y xorg xinit build-essential libx11-dev libxinerama-dev libxft-dev libimlib2-dev libxcb1-dev libxcb-res0-dev libconfig-dev libdbus-1-dev libegl-dev libev-dev libgl-dev libepoxy-dev libpcre2-dev libpixman-1-dev libx11-xcb-dev libxcb1-dev libxcb-composite0-dev libxcb-damage0-dev libxcb-dpms0-dev libxcb-glx0-dev libxcb-image0-dev libxcb-present-dev libxcb-randr0-dev libxcb-render0-dev libxcb-render-util0-dev libxcb-shape0-dev libxcb-util-dev libxcb-xfixes0-dev libxext-dev meson ninja-build uthash-dev meson unzip
            ;;
        dnf)
            $ESCALATION_TOOL dnf install -y @"Development Tools" xorg-x11-xinit xorg-x11-server-Xorg libX11-devel libXinerama-devel libXft-devel imlib2-devel libxcb-devel dbus-devel gcc git libconfig-devel libdrm-devel libev-devel libX11-devel libX11-xcb libXext-devel libxcb-devel libGL-devel libEGL-devel libepoxy-devel meson pcre2-devel pixman-devel uthash-devel xcb-util-image-devel xcb-util-renderutil-devel xorg-x11-proto-devel xcb-util-devel
            ;;
        zypper)
            $ESCALATION_TOOL zypper install -y xinit xorg-x11-server libX11-devel libXinerama-devel libXft-devel imlib2-devel libxcb-devel libxcb-devel dbus-1-devel gcc git libconfig-devel libdrm-devel libev-devel libX11-devel libX11-xcb1 libXext-devel libxcb-devel Mesa-libGL-devel Mesa-libEGL-devel libepoxy-devel meson pcre2-devel uthash-devel xcb-util-image-devel libpixman-1-0-devel xcb-util-renderutil-devel xcb-util-devel
            ;;
        *)
            printf "%b\n" "${RED}Unsupported package manager: $PACKAGER${RC}"
            exit 1
            ;;
    esac
}

install_nerd_font() {
    FONT_DIR="$HOME/.local/share/fonts"
    FONT_ZIP="$FONT_DIR/Meslo.zip"
    FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip"
    FONT_INSTALLED=$(fc-list | grep -i "Meslo")

    # Check if Meslo Nerd-font is already installed
    if [ -n "$FONT_INSTALLED" ]; then
        printf "%b\n" "${GREEN}Meslo Nerd-fonts are already installed.${RC}"
        return 0
    fi

    printf "%b\n" "${YELLOW}Installing Meslo Nerd-fonts${RC}"

    # Create the fonts directory if it doesn't exist
    if [ ! -d "$FONT_DIR" ]; then
        if ! mkdir -p "$FONT_DIR"; then
            printf "%b\n" "${RED}Failed to create directory: $FONT_DIR${RC}"
            return 1
        fi
    else
        printf "%b\n" "${YELLOW}$FONT_DIR exists, skipping creation.${RC}"
    fi

    # Check if the font zip file already exists
    if [ ! -f "$FONT_ZIP" ]; then
        # Download the font zip file
        wget -P "$FONT_DIR" "$FONT_URL" || {
            printf "%b\n" "${RED}Failed to download Meslo Nerd-fonts from $FONT_URL${RC}"
            return 1
        }
    else
        printf "%b\n" "${YELLOW}Meslo.zip already exists in $FONT_DIR, skipping download.${RC}"
    fi

    # Unzip the font file if it hasn't been unzipped yet
    if [ ! -d "$FONT_DIR/Meslo" ]; then
        unzip "$FONT_ZIP" -d "$FONT_DIR" || {
            printf "%b\n" "${RED}Failed to unzip $FONT_ZIP${RC}"
            return 1
        }
    else
        printf "%b\n" "${YELLOW}Meslo font files already unzipped in $FONT_DIR, skipping unzip.${RC}"
    fi

    # Remove the zip file
    rm "$FONT_ZIP" || {
        printf "%b\n" "${RED}Failed to remove $FONT_ZIP${RC}"
        return 1
    }

    # Rebuild the font cache
    fc-cache -fv || {
        printf "%b\n" "${RED}Failed to rebuild font cache${RC}"
        return 1
    }

    printf "%b\n" "${GREEN}Meslo Nerd-fonts installed successfully${RC}"
}

picom_animations() {
    # Clone the repository in the home/build directory
    mkdir -p ~/build
    if [ ! -d ~/build/picom ]; then
        if ! git clone https://github.com/FT-Labs/picom.git ~/build/picom; then
            printf "%b\n" "${RED}Failed to clone the repository${RC}"
            return 1
        fi
    else
        printf "%b\n" "${YELLOW}Repository already exists, skipping clone${RC}"
    fi

    cd ~/build/picom || { printf "%b\n" "${RED}Failed to change directory to picom${RC}"; return 1; }

    # Build the project
    if ! meson setup --buildtype=release build; then
        printf "%b\n" "${RED}Meson setup failed${RC}"
        return 1
    fi

    if ! ninja -C build; then
        printf "%b\n" "${RED}Ninja build failed${RC}"
        return 1
    fi

    if ! $ESCALATION_TOOL ninja -C build install; then
        printf "%b\n" "${RED}Failed to install the built binary${RC}"
        return 1
    fi

    printf "%b\n" "${GREEN}Picom animations installed successfully${RC}"
}

clone_config_folders() {
    # Ensure the target directory exists
    [ ! -d ~/.config ] && mkdir -p ~/.config

    # Iterate over all directories in config/*
    for dir in config/*/; do
        # Extract the directory name
        dir_name=$(basename "$dir")

        # Clone the directory to ~/.config/
        if [ -d "$dir" ]; then
            cp -r "$dir" ~/.config/
            printf "%b\n" "${GREEN}Cloned $dir_name to ~/.config/${RC}"
        else
            printf "%b\n" "${YELLOW}Directory $dir_name does not exist, skipping${RC}"
        fi
    done
}

configure_backgrounds() {
    # Set the variable BG_DIR to the path where backgrounds will be stored
    BG_DIR="$HOME/Pictures/backgrounds"

    # Check if the ~/Pictures directory exists
    if [ ! -d "$HOME/Pictures" ]; then
        printf "%b\n" "${YELLOW}Pictures directory does not exist, creating it.${RC}"
        mkdir -p "$HOME/Pictures" || {
            printf "%b\n" "${RED}Failed to create Pictures directory.${RC}"
            return 1
        }
    fi

    # Check if the backgrounds directory (BG_DIR) exists
    if [ ! -d "$BG_DIR" ]; then
        printf "%b\n" "${YELLOW}Backgrounds directory does not exist, downloading backgrounds.${RC}"
        if ! git clone https://github.com/ChrisTitusTech/nord-background.git "$BG_DIR"; then
            printf "%b\n" "${RED}Failed to clone the repository.${RC}"
            return 1
        fi
        printf "%b\n" "${GREEN}Downloaded desktop backgrounds to $BG_DIR.${RC}"
    else
        printf "%b\n" "${YELLOW}Backgrounds directory already exists at $BG_DIR, skipping download.${RC}"
    fi
}

setupDisplayManager() {
    setup_autologin="$1"
    printf "%b\n" "${YELLOW}Setting up Display Manager${RC}"

    if [ "$setup_autologin" = "y" ] || [ "$setup_autologin" = "Y" ]; then
        existing_dm=""
        for dm in sddm lightdm gdm; do
            if command -v $dm >/dev/null 2>&1; then
                existing_dm=$dm
                break
            fi
        done

        if [ -n "$existing_dm" ]; then
            printf "%b\n" "${YELLOW}Existing display manager detected: $existing_dm${RC}"
            printf "%b" "${CYAN}Do you want to use $existing_dm? (y/n): ${RC}"
            read -r use_existing_dm
            if [ "$use_existing_dm" = "y" ] || [ "$use_existing_dm" = "Y" ]; then
                DM=$existing_dm
            fi
        fi

        # If no existing DM is chosen, select based on distribution
        if [ -z "$DM" ]; then
            case "$DTYPE" in
                arch|fedora|ubuntu|opensuse-tumbleweed)
                    DM="sddm"
                    ;;
                debian)
                    DM="lightdm"
                    ;;
                *)
                    printf "%b\n" "${YELLOW}Unsupported distribution. Defaulting to SDDM.${RC}"
                    DM="sddm"
                    ;;
            esac

            # Install the chosen display manager if not already installed
            if ! command -v $DM >/dev/null 2>&1; then
                printf "%b\n" "${YELLOW}Installing $DM...${RC}"
                case $PACKAGER in
                    pacman)
                        $ESCALATION_TOOL pacman -S --needed --noconfirm $DM
                        ;;
                    apt|nala)
                        $ESCALATION_TOOL $PACKAGER install -y $DM
                        ;;
                    dnf)
                        $ESCALATION_TOOL dnf install -y $DM
                        ;;
                    zypper)
                        $ESCALATION_TOOL zypper install -y $DM
                        ;;
                    *)
                        printf "%b\n" "${RED}Unsupported package manager. Please install $DM manually.${RC}"
                        return 1
                        ;;
                esac
            fi
        fi

        printf "%b\n" "${YELLOW}Configuring $DM for autologin${RC}"

        # Configure the chosen display manager for autologin
        case $DM in
            "sddm")
                # SDDM configuration
                SDDM_CONF="/etc/sddm.conf"
                if [ ! -f "$SDDM_CONF" ]; then
                    echo "[Autologin]" | $ESCALATION_TOOL tee "$SDDM_CONF"
                else
                    $ESCALATION_TOOL sed -i '/^\[Autologin\]/d' "$SDDM_CONF"
                    $ESCALATION_TOOL sed -i '/^User=/d' "$SDDM_CONF"
                    $ESCALATION_TOOL sed -i '/^Session=/d' "$SDDM_CONF"
                    echo "[Autologin]" | $ESCALATION_TOOL tee -a "$SDDM_CONF"
                fi
                echo "User=$USER" | $ESCALATION_TOOL tee -a "$SDDM_CONF"
                echo "Session=dwm" | $ESCALATION_TOOL tee -a "$SDDM_CONF"
                ;;
            "lightdm")
                # LightDM configuration
                LIGHTDM_CONF="/etc/lightdm/lightdm.conf"
                if [ ! -f "$LIGHTDM_CONF" ]; then
                    printf "%b\n" "${YELLOW}LightDM configuration file not found. Attempting to create it.${RC}"
                    $ESCALATION_TOOL mkdir -p /etc/lightdm
                    echo "[Seat:*]" | $ESCALATION_TOOL tee "$LIGHTDM_CONF"
                fi
                
                if [ -f "$LIGHTDM_CONF" ]; then
                    if ! grep -q "^\[Seat:\*\]" "$LIGHTDM_CONF"; then
                        echo "[Seat:*]" | $ESCALATION_TOOL tee -a "$LIGHTDM_CONF"
                    fi
                    $ESCALATION_TOOL sed -i "/^\[Seat:\*\]/a autologin-user=$USER" "$LIGHTDM_CONF"
                    $ESCALATION_TOOL sed -i "/^\[Seat:\*\]/a autologin-session=dwm" "$LIGHTDM_CONF"
                    printf "%b\n" "${GREEN}LightDM configured for autologin.${RC}"
                else
                    printf "%b\n" "${RED}Failed to create or find LightDM configuration file. Autologin setup failed.${RC}"
                fi
                ;;
            "gdm")
                # GDM configuration
                GDM_CONF="/etc/gdm/custom.conf"
                if [ ! -f "$GDM_CONF" ]; then
                    printf "%b\n" "${YELLOW}GDM configuration file not found. Attempting to create it.${RC}"
                    $ESCALATION_TOOL mkdir -p /etc/gdm
                    echo "[daemon]" | $ESCALATION_TOOL tee "$GDM_CONF"
                fi
                
                if [ -f "$GDM_CONF" ]; then
                    if ! grep -q "^\[daemon\]" "$GDM_CONF"; then
                        echo "[daemon]" | $ESCALATION_TOOL tee -a "$GDM_CONF"
                    fi
                    $ESCALATION_TOOL sed -i "/^\[daemon\]/a AutomaticLoginEnable=True" "$GDM_CONF"
                    $ESCALATION_TOOL sed -i "/^\[daemon\]/a AutomaticLogin=$USER" "$GDM_CONF"
                    
                    # Set DWM as the default session
                    if [ -d "/usr/share/xsessions" ]; then
                        echo "[Desktop]" | $ESCALATION_TOOL tee /usr/share/xsessions/dwm.desktop
                        echo "Name=DWM" | $ESCALATION_TOOL tee -a /usr/share/xsessions/dwm.desktop
                        echo "Exec=dwm" | $ESCALATION_TOOL tee -a /usr/share/xsessions/dwm.desktop
                    fi
                    
                    printf "%b\n" "${GREEN}GDM configured for autologin.${RC}"
                else
                    printf "%b\n" "${RED}Failed to create or find GDM configuration file. Autologin setup failed.${RC}"
                fi
                ;;
        esac

        $ESCALATION_TOOL systemctl enable $DM.service

        $ESCALATION_TOOL systemctl set-default graphical.target

        printf "%b\n" "${GREEN}Display Manager setup complete with autologin.${RC}"
    else
        printf "%b\n" "${YELLOW}Autologin not selected. Setting up for manual login.${RC}"
        
        $ESCALATION_TOOL systemctl set-default multi-user.target
        
        printf "%b\n" "${YELLOW}Creating .xinitrc file in the home directory.${RC}"
        echo "exec dwm" > "$HOME/.xinitrc"
        printf "%b\n" "${GREEN}.xinitrc file created with 'exec dwm'${RC}"
    fi
}

# Main execution flow
install_nerd_font
clone_config_folders
configure_backgrounds
setupDWM
picom_animations
makeDWM

# Move setupDisplayManager to the end and pass the autologin choice
setupDisplayManager "$setup_autologin"

printf "%b\n" "${GREEN}DWM installation and setup complete.${RC}"