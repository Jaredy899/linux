#!/bin/sh -e

# Function to detect the escalation tool (default is sudo)
detect_escalation_tool() {
    if [ "$(id -u)" -ne 0 ]; then
        if command -v sudo >/dev/null 2>&1; then
            ESCALATION_TOOL="sudo"
        else
            echo "No escalation tool found (sudo not installed), please run the script as root."
            exit 1
        fi
    else
        ESCALATION_TOOL=""
    fi
}

# Function to detect the package manager
detect_packager() {
    if command -v pacman >/dev/null 2>&1; then
        PACKAGER="pacman"
    elif command -v dnf >/dev/null 2>&1; then
        PACKAGER="dnf"
    elif command -v apt >/dev/null 2>&1; then
        PACKAGER="apt"
    elif command -v zypper >/dev/null 2>&1; then
        PACKAGER="zypper"
    else
        echo "No supported package manager found."
        exit 1
    fi
}

# Function to detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [ "$ID" = "opensuse" ] && [ "$VERSION_ID" = "tumbleweed" ]; then
            echo "opensuse-tumbleweed"
        else
            echo "$ID"
        fi
    else
        echo "unknown"
    fi
}

# Function to install packages based on distribution
install_packages() {
    local distro="$1"
    case "$distro" in
        ubuntu|debian)
            packages="nano thunar vlc feh pavucontrol pipewire pipewire-audio-client-libraries pipewire-pulse pipewire-alsa"
            sudo apt-get update
            sudo apt-get install -y $packages
            ;;
        fedora|centos|rhel)
            packages="nano thunar vlc network-manager-applet feh pavucontrol"
            sudo dnf update -y
            sudo dnf install -y $packages
            ;;
        arch)
            packages="nano thunar vlc nm-connection-editor feh pavucontrol pipewire pipewire-pulse pipewire-alsa"
            sudo pacman -Syu --noconfirm $packages
            ;;
        opensuse-tumbleweed)
            packages="nano thunar vlc NetworkManager-applet feh pavucontrol"
            sudo zypper refresh
            sudo zypper install -y $packages
            ;;
        *)
            echo "Unsupported distribution: $distro"
            exit 1
            ;;
    esac

    # Create or update the .xprofile file to autostart nm-applet for all distros
    if [ ! -f "$HOME/.xprofile" ]; then
        echo "Creating .xprofile and adding nm-applet autostart..."
        echo "nm-applet &" > "$HOME/.xprofile"
    else
        if ! grep -q "nm-applet &" "$HOME/.xprofile"; then
            echo "Adding nm-applet autostart to existing .xprofile..."
            echo "nm-applet &" >> "$HOME/.xprofile"
        fi
    fi
}

# Main function to orchestrate all actions
main() {
    distro=$(detect_distro)
    if [ "$distro" = "unknown" ]; then
        echo "Unable to detect Linux distribution. Exiting."
        exit 1
    fi

    install_packages "$distro"
}

makeDWM() {
    cd "$HOME" && git clone https://github.com/ChrisTitusTech/dwm-titus.git # CD to Home directory to install dwm-titus
    cd dwm-titus/
    $ESCALATION_TOOL make clean install
    
    # Install slstatus
    cd slstatus/
    $ESCALATION_TOOL make clean install
    cd ..  # Return to the dwm-titus directory
}

setupDWM() {
    echo "Installing DWM-Titus if not already installed"
    case "$PACKAGER" in
        pacman)
            $ESCALATION_TOOL "$PACKAGER" -S --needed --noconfirm xorg-xinit xorg-server base-devel libx11 libxinerama libxft imlib2 libxcb meson libev uthash libconfig
            ;;
        apt)
            $ESCALATION_TOOL apt-get install -y xorg xinit build-essential libx11-dev libxinerama-dev libxft-dev libimlib2-dev libxcb1-dev libxcb-res0-dev libconfig-dev libdbus-1-dev libegl-dev libev-dev libgl-dev libepoxy-dev libpcre2-dev libpixman-1-dev libx11-xcb-dev libxcb1-dev libxcb-composite0-dev libxcb-damage0-dev libxcb-dpms0-dev libxcb-glx0-dev libxcb-image0-dev libxcb-present-dev libxcb-randr0-dev libxcb-render0-dev libxcb-render-util0-dev libxcb-shape0-dev libxcb-util-dev libxcb-xfixes0-dev libxext-dev meson ninja-build uthash-dev meson unzip
            ;;
        dnf)
            $ESCALATION_TOOL "$PACKAGER" groupinstall -y "Development Tools"
            $ESCALATION_TOOL "$PACKAGER" install -y xorg-x11-xinit xorg-x11-server-Xorg libX11-devel libXinerama-devel libXft-devel imlib2-devel libxcb-devel dbus-devel gcc git libconfig-devel libdrm-devel libev-devel libX11-devel libX11-xcb libXext-devel libxcb-devel libGL-devel libEGL-devel libepoxy-devel meson pcre2-devel pixman-devel uthash-devel xcb-util-image-devel xcb-util-renderutil-devel xorg-x11-proto-devel xcb-util-devel meson
            ;;
        zypper)
            $ESCALATION_TOOL "$PACKAGER" install -y xorg-x11-server xinit gcc make libX11-devel libXinerama-devel libXft-devel imlib2-devel libev-devel libxcb-devel dbus-1-devel git meson uthash-devel
            ;;
        *)
            echo "Unsupported package manager: $PACKAGER"
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
        echo "Meslo Nerd-fonts are already installed."
        return 0
    fi

    echo "Installing Meslo Nerd-fonts"

    # Create the fonts directory if it doesn't exist
    if [ ! -d "$FONT_DIR" ]; then
        mkdir -p "$FONT_DIR" || {
            echo "Failed to create directory: $FONT_DIR"
            return 1
        }
    else
        echo "$FONT_DIR exists, skipping creation."
    fi

    # Check if the font zip file already exists
    if [ ! -f "$FONT_ZIP" ]; then
        # Download the font zip file
        wget -P "$FONT_DIR" "$FONT_URL" || {
            echo "Failed to download Meslo Nerd-fonts from $FONT_URL"
            return 1
        }
    else
        echo "Meslo.zip already exists in $FONT_DIR, skipping download."
    fi

    # Unzip the font file if it hasn't been unzipped yet
    if [ ! -d "$FONT_DIR/Meslo" ]; then
        unzip "$FONT_ZIP" -d "$FONT_DIR" || {
            echo "Failed to unzip $FONT_ZIP"
            return 1
        }
    else
        echo "Meslo font files already unzipped in $FONT_DIR, skipping unzip."
    fi

    # Remove the zip file
    rm "$FONT_ZIP" || {
        echo "Failed to remove $FONT_ZIP"
        return 1
    }

    # Rebuild the font cache
    fc-cache -fv || {
        echo "Failed to rebuild font cache"
        return 1
    }

    echo "Meslo Nerd-fonts installed successfully"
}

picom_animations() {
    # Clone the repository in the home/build directory
    mkdir -p ~/build
    if [ ! -d ~/build/picom ]; then
        if ! git clone https://github.com/FT-Labs/picom.git ~/build/picom; then
            echo "Failed to clone the repository"
            return 1
        fi
    else
        echo "Repository already exists, skipping clone"
    fi

    cd ~/build/picom || { echo "Failed to change directory to picom"; return 1; }

    # Build the project
    if ! meson setup --buildtype=release build; then
        echo "Meson setup failed"
        return 1
    fi

    if ! ninja -C build; then
        echo "Ninja build failed"
        return 1
    fi

    # Install the built binary
    if ! sudo ninja -C build install; then
        echo "Failed to install the built binary"
        return 1
    fi

    echo "Picom animations installed successfully"
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
            echo "Cloned $dir_name to ~/.config/"
        else
            echo "Directory $dir_name does not exist, skipping"
        fi
    done
}

configure_backgrounds() {
    # Set the variable BG_DIR to the path where backgrounds will be stored
    BG_DIR="$HOME/Pictures/backgrounds"

    # Check if the ~/Pictures directory exists
    if [ ! -d "$HOME/Pictures" ]; then
        # If it doesn't exist, create the ~/Pictures directory
        echo "Pictures directory does not exist, creating it."
        mkdir -p "$HOME/Pictures" || {
            echo "Failed to create Pictures directory."
            return 1
        }
    fi

    # Check if the backgrounds directory (BG_DIR) exists
    if [ ! -d "$BG_DIR" ]; then
        echo "Backgrounds directory does not exist, downloading backgrounds."
        # If the backgrounds directory doesn't exist, clone the repository containing backgrounds
        if ! git clone https://github.com/ChrisTitusTech/nord-background.git "$BG_DIR"; then
            echo "Failed to clone the repository."
            return 1
        fi
        echo "Downloaded desktop backgrounds to $BG_DIR."
    else
        echo "Backgrounds directory already exists at $BG_DIR, skipping download."
    fi
}

setupDisplayManager() {
    echo "Setting up Display Manager"

    # Ask if the user wants to autologin
    read -p "Do you want to set up autologin? (y/n): " setup_autologin

    if [ "$setup_autologin" = "y" ] || [ "$setup_autologin" = "Y" ]; then
        # Detect the current distribution
        distro=$(detect_distro)

        # Check if a display manager is already installed
        existing_dm=""
        for dm in sddm lightdm gdm; do
            if command -v $dm >/dev/null 2>&1; then
                existing_dm=$dm
                break
            fi
        done

        if [ -n "$existing_dm" ]; then
            echo "Existing display manager detected: $existing_dm"
            read -p "Do you want to use $existing_dm? (y/n): " use_existing_dm
            if [ "$use_existing_dm" = "y" ] || [ "$use_existing_dm" = "Y" ]; then
                DM=$existing_dm
            fi
        fi

        # If no existing DM is chosen, select based on distribution
        if [ -z "$DM" ]; then
            case "$distro" in
                arch|fedora|ubuntu)
                    DM="sddm"
                    ;;
                debian|opensuse-tumbleweed)
                    DM="lightdm"
                    ;;
                *)
                    echo "Unsupported distribution. Defaulting to SDDM."
                    DM="sddm"
                    ;;
            esac

            # Install the chosen display manager if not already installed
            if ! command -v $DM >/dev/null 2>&1; then
                echo "Installing $DM..."
                case $PACKAGER in
                    pacman)
                        sudo pacman -S --noconfirm $DM
                        ;;
                    apt)
                        sudo apt install -y $DM
                        ;;
                    dnf)
                        sudo dnf install -y $DM
                        ;;
                    zypper)
                        sudo zypper install -y $DM
                        ;;
                    *)
                        echo "Unsupported package manager. Please install $DM manually."
                        return 1
                        ;;
                esac
            fi
        fi

        echo "Configuring $DM for autologin"

        # Configure the chosen display manager for autologin
        case $DM in
            "sddm")
                # SDDM configuration
                SDDM_CONF="/etc/sddm.conf"
                if [ ! -f "$SDDM_CONF" ]; then
                    echo "[Autologin]" | sudo tee "$SDDM_CONF"
                else
                    sudo sed -i '/^\[Autologin\]/d' "$SDDM_CONF"
                    sudo sed -i '/^User=/d' "$SDDM_CONF"
                    sudo sed -i '/^Session=/d' "$SDDM_CONF"
                    echo "[Autologin]" | sudo tee -a "$SDDM_CONF"
                fi
                echo "User=$USER" | sudo tee -a "$SDDM_CONF"
                echo "Session=dwm" | sudo tee -a "$SDDM_CONF"
                ;;
            "lightdm")
                # LightDM configuration
                LIGHTDM_CONF="/etc/lightdm/lightdm.conf"
                if [ ! -f "$LIGHTDM_CONF" ]; then
                    echo "LightDM configuration file not found. Attempting to create it."
                    sudo mkdir -p /etc/lightdm
                    echo "[Seat:*]" | sudo tee "$LIGHTDM_CONF"
                fi
                
                if [ -f "$LIGHTDM_CONF" ]; then
                    if ! grep -q "^\[Seat:\*\]" "$LIGHTDM_CONF"; then
                        echo "[Seat:*]" | sudo tee -a "$LIGHTDM_CONF"
                    fi
                    sudo sed -i "/^\[Seat:\*\]/a autologin-user=$USER" "$LIGHTDM_CONF"
                    sudo sed -i "/^\[Seat:\*\]/a autologin-session=dwm" "$LIGHTDM_CONF"
                    echo "LightDM configured for autologin."
                else
                    echo "Failed to create or find LightDM configuration file. Autologin setup failed."
                fi
                ;;
            "gdm")
                # GDM configuration
                GDM_CONF="/etc/gdm/custom.conf"
                if [ ! -f "$GDM_CONF" ]; then
                    echo "GDM configuration file not found. Attempting to create it."
                    sudo mkdir -p /etc/gdm
                    echo "[daemon]" | sudo tee "$GDM_CONF"
                fi
                
                if [ -f "$GDM_CONF" ]; then
                    if ! grep -q "^\[daemon\]" "$GDM_CONF"; then
                        echo "[daemon]" | sudo tee -a "$GDM_CONF"
                    fi
                    sudo sed -i "/^\[daemon\]/a AutomaticLoginEnable=True" "$GDM_CONF"
                    sudo sed -i "/^\[daemon\]/a AutomaticLogin=$USER" "$GDM_CONF"
                    
                    # Set DWM as the default session
                    if [ -d "/usr/share/xsessions" ]; then
                        echo "[Desktop]" | sudo tee /usr/share/xsessions/dwm.desktop
                        echo "Name=DWM" | sudo tee -a /usr/share/xsessions/dwm.desktop
                        echo "Exec=dwm" | sudo tee -a /usr/share/xsessions/dwm.desktop
                    fi
                    
                    echo "GDM configured for autologin."
                else
                    echo "Failed to create or find GDM configuration file. Autologin setup failed."
                fi
                ;;
        esac

        # Enable the display manager service
        sudo systemctl enable $DM.service

        # Set the system to boot into graphical.target
        echo "Setting system to boot into graphical.target"
        sudo systemctl set-default graphical.target

        echo "Display Manager setup complete with autologin."
    else
        echo "Autologin not selected. Setting up for manual login."
        
        # Set the system to boot into multi-user.target
        sudo systemctl set-default multi-user.target
        
        # Create .xinitrc file
        echo "Creating .xinitrc file in the home directory."
        echo "exec dwm" > "$HOME/.xinitrc"
        echo ".xinitrc file created with 'exec dwm'"
    fi
}

# Function Calls
detect_escalation_tool || true
detect_packager || true
setupDisplayManager || true
install_nerd_font || true
clone_config_folders || true
configure_backgrounds || true
setupDWM || true
picom_animations || true
makeDWM || true

# Execute main
main || true
