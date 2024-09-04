#!/bin/bash

# Source the common.sh script
GITHUB_BASE_URL="https://raw.githubusercontent.com/Jaredy899/linux/main"
COMMON_SCRIPT_URL="${GITHUB_BASE_URL}/common.sh"

# Download and source the common.sh script if it's not already present
if [ ! -f "common.sh" ]; then
    echo "Downloading common.sh..."
    curl -s -O "${COMMON_SCRIPT_URL}"
fi
source ./common.sh

# Run environment checks using common.sh
checkEnv

# Detect the Linux distribution
checkDistro
distro="$DTYPE"

# Define packages for different distributions
case "$distro" in
    ubuntu|debian)
        # Essential packages
        packages="nano thunar vlc pulseaudio alsa-utils pavucontrol fonts-firacode network-manager-gnome"
        
        # Install wget if not already installed (required for adding the Mozilla APT repository)
        if ! command_exists wget; then
            echo "Installing wget..."
            $ESCALATION_TOOL $PACKAGER install -y wget
        fi

        # Add Mozilla APT repository for Firefox installation
        echo "Adding Mozilla APT repository for Firefox installation..."
        $ESCALATION_TOOL install -d -m 0755 /etc/apt/keyrings
        wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | $ESCALATION_TOOL tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null
        
        # Verify the key fingerprint
        fingerprint_check=$(gpg -n -q --import --import-options import-show /etc/apt/keyrings/packages.mozilla.org.asc | awk '/pub/{getline; gsub(/^ +| +$/,""); if($0 == "35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3") print "match"; else print "no_match"}')
        if [[ "$fingerprint_check" == "match" ]]; then
            echo "The key fingerprint matches."
        else
            echo "Verification failed: the fingerprint does not match the expected one."
            exit 1
        fi
        
        # Add Mozilla APT repository to sources list
        echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | $ESCALATION_TOOL tee /etc/apt/sources.list.d/mozilla.list > /dev/null
        
        # Configure APT to prioritize packages from the Mozilla repository
        echo '
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
' | $ESCALATION_TOOL tee /etc/apt/preferences.d/mozilla > /dev/null
        
        # Update package list and install Firefox
        echo "Updating package list and installing Firefox..."
        $ESCALATION_TOOL $PACKAGER update -y
        $ESCALATION_TOOL $PACKAGER install -y $packages firefox
        ;;
    fedora|centos|rhel)
        packages="nano thunar vlc pulseaudio alsa-utils pavucontrol fira-code-fonts NetworkManager-tui firefox"
        echo "Updating package database and installing essential packages..."
        $ESCALATION_TOOL $PACKAGER update -y
        $ESCALATION_TOOL $PACKAGER install -y $packages
        ;;
    arch)
        packages="nano thunar vlc pulseaudio pulseaudio-alsa alsa-utils pavucontrol ttf-firacode-nerd nm-connection-editor firefox"
        echo "Updating package database and installing essential packages..."
        $ESCALATION_TOOL $PACKAGER -Syu --noconfirm $packages
        ;;
    *)
        echo "Unsupported distribution: $distro"
        exit 1
        ;;
esac

# Ask if user wants to replace configuration files
read -p "Do you want to replace configuration files from GitHub? (y/n): " replace_configs

if [[ $replace_configs == "y" || $replace_configs == "Y" ]]; then
    echo "Downloading and replacing configuration files from GitHub..."

    # Define base URL
    BASE_URL="https://raw.githubusercontent.com/Jaredy899/linux/main/config_changes"

    # Replace .bashrc, config.jsonc, starship.toml in /linuxtoolbox/mybash/
    MYBASH_DIR=~/linuxtoolbox/mybash
    if [[ ! -d $MYBASH_DIR ]]; then
        mkdir -p $MYBASH_DIR
    fi
    curl -o $MYBASH_DIR/.bashrc "$BASE_URL/.bashrc"
    curl -o $MYBASH_DIR/config.jsonc "$BASE_URL/config.jsonc"
    curl -o $MYBASH_DIR/starship.toml "$BASE_URL/starship.toml"

    # Replace config.h in /dwm-titus/
    DWM_TITUS_DIR=~/dwm-titus
    if [[ ! -d $DWM_TITUS_DIR ]]; then
        mkdir -p $DWM_TITUS_DIR
    fi
    curl -o $DWM_TITUS_DIR/config.h "$BASE_URL/config.h"

    # Compile and install dwm with the new config.h
    if [[ -d $DWM_TITUS_DIR ]]; then
        echo "Compiling and installing dwm with the new configuration..."
        cd $DWM_TITUS_DIR
        $ESCALATION_TOOL make clean install
    else
        echo "Directory $DWM_TITUS_DIR not found, skipping dwm compilation."
    fi

    # Ensure clean install for slstatus inside the DWM_TITUS_DIR
    SLSTATUS_DIR="$DWM_TITUS_DIR/slstatus"
    if [[ -d $SLSTATUS_DIR ]]; then
        echo "Compiling and installing slstatus..."
        cd $SLSTATUS_DIR
        $ESCALATION_TOOL make clean install
    else
        echo "Directory $SLSTATUS_DIR not found, skipping slstatus installation."
    fi

else
    echo "Configuration files not replaced."
fi