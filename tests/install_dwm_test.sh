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
    else
        echo "No supported package manager found."
        exit 1
    fi
}

# Function to detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

# Function to install packages based on distribution
install_packages() {
    local distro="$1"
    case "$distro" in
        ubuntu|debian)
            # List of packages to install first
            packages="nano thunar vlc feh pavucontrol pipewire pipewire-audio-client-libraries pipewire-pulse pipewire-alsa"

            # Install the initial set of packages
            echo "Installing basic packages..."
            sudo apt-get update
            sudo apt-get install -y $packages

            # Check if wget is installed, if not install it
            if ! command -v wget >/dev/null 2>&1; then
                echo "Installing wget..."
                sudo apt-get install -y wget
            fi
            ;;
        fedora|centos|rhel)
            packages="nano thunar vlc NetworkManager network-manager-applet firefox chromium feh pavucontrol"
            sudo dnf update -y
            sudo dnf install -y $packages
            ;;
        arch)
            packages="nano thunar vlc networkmanager nm-connection-editor firefox chromium feh pavucontrol pipewire pipewire-pulse pipewire-alsa"
            sudo pacman -Syu --noconfirm $packages
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

# Function to replace configuration files from GitHub
replace_configs() {
    BASE_URL="https://raw.githubusercontent.com/Jaredy899/linux/main/config_changes"
    MYBASH_DIR=~/.local/share/mybash
    DWM_TITUS_DIR=~/dwm-titus

    mkdir -p "$MYBASH_DIR"
    curl -o "$MYBASH_DIR/.bashrc" "$BASE_URL/.bashrc"
    curl -o "$MYBASH_DIR/config.jsonc" "$BASE_URL/config.jsonc"
    curl -o "$MYBASH_DIR/starship.toml" "$BASE_URL/starship.toml"

    mkdir -p "$DWM_TITUS_DIR"
    curl -o "$DWM_TITUS_DIR/config.h" "$BASE_URL/config.h"

    if [ -d $DWM_TITUS_DIR ]; then
        cd $DWM_TITUS_DIR
        sudo make clean install
    fi

    SLSTATUS_DIR="$DWM_TITUS_DIR/slstatus"
    if [ -d $SLSTATUS_DIR ]; then
        cd $SLSTATUS_DIR
        sudo make clean install
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

    read -p "Do you want to replace configuration files from GitHub? (y/n): " replace_configs_input
    if [ "$replace_configs_input" = "y" ] || [ "$replace_configs_input" = "Y" ]; then
        replace_configs
    else
        echo "Configuration files not replaced."
    fi
}

makeDWM() {
    cd "$HOME" && git clone https://github.com/ChrisTitusTech/dwm-titus.git # CD to Home directory to install dwm-titus
    cd dwm-titus/
    $ESCALATION_TOOL make clean install
}

setupDWM() {
    echo "Installing DWM-Titus if not already installed"
    case "$PACKAGER" in
        pacman)
            $ESCALATION_TOOL "$PACKAGER" -S --needed --noconfirm xorg-xinit xorg-server base-devel libx11 libxinerama libxft imlib2 libxcb meson libev uthash libconfig
            ;;
        apt)
            $ESCALATION_TOOL "$PACKAGER" install -y xorg xinit build-essential libx11-dev libxinerama-dev libxft-dev libimlib2-dev libxcb1-dev libxcb-res0-dev libconfig-dev libdbus-1-dev libegl-dev libev-dev libgl-dev libepoxy-dev libpcre2-dev libpixman-1-dev libx11-xcb-dev libxcb1-dev libxcb-composite0-dev libxcb-damage0-dev libxcb-dpms0-dev libxcb-glx0-dev libxcb-image0-dev libxcb-present-dev libxcb-randr0-dev libxcb-render0-dev libxcb-render-util0-dev libxcb-shape0-dev libxcb-util-dev libxcb-xfixes0-dev libxext-dev meson ninja-build uthash-dev meson unzip
            ;;
        dnf)
            $ESCALATION_TOOL "$PACKAGER" groupinstall -y "Development Tools"
            $ESCALATION_TOOL "$PACKAGER" install -y xorg-x11-xinit xorg-x11-server-Xorg libX11-devel libXinerama-devel libXft-devel imlib2-devel libxcb-devel dbus-devel gcc git libconfig-devel libdrm-devel libev-devel libX11-devel libX11-xcb libXext-devel libxcb-devel libGL-devel libEGL-devel libepoxy-devel meson pcre2-devel pixman-devel uthash-devel xcb-util-image-devel xcb-util-renderutil-devel xorg-x11-proto-devel xcb-util-devel meson
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

    currentdm="none"
    for dm in gdm sddm lightdm; do
        if systemctl is-active --quiet $dm.service; then
            currentdm=$dm
            break
        fi
    done
    echo "Current display manager: $currentdm"

    if [ "$currentdm" = "none" ]; then
        echo "No active display manager found. Which one would you like to install?"
        echo "1) SDDM"
        echo "2) LightDM"
        echo "3) GDM"
        read -p "Enter your choice (1-3): " dm_choice

        case $dm_choice in
            1) DM="sddm" ;;
            2) DM="lightdm" ;;
            3) DM="gdm" ;;
            *) 
                echo "Invalid choice. Defaulting to SDDM."
                DM="sddm"
                ;;
        esac

        echo "Installing $DM"
        case "$PACKAGER" in
            pacman)
                $ESCALATION_TOOL "$PACKAGER" -S --needed --noconfirm $DM
                ;;
            apt)
                $ESCALATION_TOOL "$PACKAGER" install -y $DM
                ;;
            dnf)
                $ESCALATION_TOOL "$PACKAGER" install -y $DM
                ;;
            *)
                echo "Unsupported package manager: $PACKAGER"
                exit 1
                ;;
        esac
        echo "$DM installed successfully"
        sudo systemctl enable $DM
    fi

    # Clear the screen
    clear

    # Prompt user for auto-login
    echo "Do you want to enable auto-login?"

    # Provide a basic menu for Yes/No options
    while true; do
        echo "1) Yes"
        echo "2) No"
        read -p "Select an option [1/2]: " choice

        case $choice in
            1)
                echo "You selected Yes"
                enable_autologin="yes"
                break
                ;;
            2)
                echo "You selected No"
                enable_autologin="no"
                break
                ;;
            *)
                echo "Invalid option. Please choose 1 or 2."
                ;;
        esac
    done

    if [ "$enable_autologin" = "yes" ]; then
        echo "Configuring display manager for autologin"

        # Detect the installed display manager
        if [ -f "/etc/sddm.conf" ] || [ -d "/etc/sddm.conf.d" ]; then
            DM="sddm"
        elif [ -f "/etc/lightdm/lightdm.conf" ]; then
            DM="lightdm"
        elif [ -f "/etc/gdm/custom.conf" ]; then
            DM="gdm"
        else
            echo "No supported display manager found. Skipping autologin configuration."
            DM=""
        fi

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
                sudo sed -i "s/^#\?autologin-user=.*/autologin-user=$USER/" /etc/lightdm/lightdm.conf
                sudo sed -i "s/^#\?autologin-session=.*/autologin-session=dwm/" /etc/lightdm/lightdm.conf
                ;;
            "gdm")
                # GDM configuration
                sudo sed -i "s/^#\?  AutomaticLoginEnable=.*/AutomaticLoginEnable=True/" /etc/gdm/custom.conf
                sudo sed -i "s/^#\?  AutomaticLogin=.*/AutomaticLogin=$USER/" /etc/gdm/custom.conf
                # Note: GDM doesn't have a straightforward way to set the default session, so users might need to select DWM manually on first login
                ;;
        esac

        # Enable graphical.target for auto-login
        echo "Setting system to boot into graphical.target"
        sudo systemctl set-default graphical.target
    else
        # Set the default target to multi-user.target (console mode)
        echo "Auto-login disabled. Setting system to boot into console (multi-user.target)"
        sudo systemctl set-default multi-user.target

        # Create a .xinitrc file if console mode is chosen, to allow starting dwm manually
        echo "Creating .xinitrc file in the home directory"
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
