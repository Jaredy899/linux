#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status
IFS=$(printf '\n\t')

# Detect the operating system
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "Cannot detect the operating system. /etc/os-release not found."
    exit 1
fi

# Define package installation commands based on the OS
if [[ "$OS" == "arch" ]]; then
    INSTALL_CMD="sudo pacman -Syu --noconfirm"
    PACKAGES="nano xorg xorg-xinit thunar vlc pulseaudio pulseaudio-alsa alsa-utils pavucontrol firefox ttf-firacode-nerd kitty alacritty"
elif [[ "$OS" == "debian" || "$OS" == "ubuntu" ]]; then
    INSTALL_CMD="sudo apt update && sudo apt install -y"
    PACKAGES="nano xorg xorg-xinit thunar vlc pulseaudio pulseaudio-utils pavucontrol firefox fonts-firacode kitty alacritty"
else
    echo "Unsupported operating system: $OS"
    exit 1
fi

# Update package database and install essential packages
echo "Installing essential packages..."
if [[ "$OS" == "arch" ]]; then
    $INSTALL_CMD $PACKAGES
elif [[ "$OS" == "debian" || "$OS" == "ubuntu" ]]; then
    sudo apt update
    sudo apt install -y $PACKAGES
fi

# Create .xinitrc file with exec dwm
echo "exec dwm" > ~/.xinitrc

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

    # Replace kitty.conf in ~/.config/kitty/
    KITTY_CONFIG_DIR=~/.config/kitty
    if [[ ! -d $KITTY_CONFIG_DIR ]]; then
        mkdir -p $KITTY_CONFIG_DIR
    fi
    curl -o $KITTY_CONFIG_DIR/kitty.conf "$BASE_URL/kitty.conf"

    # Replace alacritty.toml in ~/.config/alacritty/
    ALACRITTY_CONFIG_DIR=~/.config/alacritty
    if [[ ! -d $ALACRITTY_CONFIG_DIR ]]; then
        mkdir -p $ALACRITTY_CONFIG_DIR
    fi
    curl -o $ALACRITTY_CONFIG_DIR/alacritty.toml "$BASE_URL/alacritty.toml"

    # Replace config.h in /dwm-titus/
    DWM_TITUS_DIR=~/dwm-titus
    if [[ ! -d $DWM_TITUS_DIR ]]; then
        mkdir -p $DWM_TITUS_DIR
    fi
    curl -o $DWM_TITUS_DIR/config.h "$BASE_URL/config.h"

    echo "Configuration files replaced."

    # Compile and install dwm with the new config.h
    if [[ -d $DWM_TITUS_DIR ]]; then
        echo "Compiling and installing dwm with the new configuration..."
        cd $DWM_TITUS_DIR
        sudo make clean install
    else
        echo "Directory $DWM_TITUS_DIR not found, skipping dwm compilation."
    fi

else
    echo "Configuration files not replaced."
fi

# Ask user if they want to install NVIDIA drivers
read -p "Do you want to install NVIDIA drivers? (y/n): " install_nvidia

if [[ $install_nvidia == "y" || $install_nvidia == "Y" ]]; then
    if [[ "$OS" == "arch" ]]; then
        # Install NVIDIA drivers for Arch
        sudo pacman -S --noconfirm nvidia nvidia-settings nvidia-utils

        # Check if dkms is installed (in case of using an LTS kernel)
        if pacman -Qs dkms > /dev/null; then
            echo "DKMS detected, rebuilding NVIDIA kernel modules."
            sudo dkms install -m nvidia -v $(pacman -Q nvidia | awk '{print $2}')
        fi

        # Regenerate initramfs
        echo "Regenerating initramfs..."
        sudo mkinitcpio -P
    elif [[ "$OS" == "debian" || "$OS" == "ubuntu" ]]; then
        # Install NVIDIA drivers for Debian/Ubuntu
        sudo apt install -y nvidia-driver nvidia-settings

        # Update initramfs
        echo "Updating initramfs..."
        sudo update-initramfs -u
    fi

    # Create or update X configuration file for NVIDIA
    echo "Creating /etc/X11/xorg.conf.d/20-nvidia.conf for NVIDIA settings..."
    sudo mkdir -p /etc/X11/xorg.conf.d
    echo -e 'Section "Device"\n  Identifier "NVIDIA GPU"\n  Driver "nvidia"\nEndSection' | sudo tee /etc/X11/xorg.conf.d/20-nvidia.conf

    echo "NVIDIA drivers installed and configured."
else
    echo "NVIDIA drivers not installed."
fi

echo "Setup complete!"
