#!/bin/bash

# Update package database and install essential packages
sudo pacman -Syu --noconfirm nano xorg xorg-xinit thunar vlc

# Install audio drivers (PulseAudio and ALSA)
sudo pacman -S --noconfirm pulseaudio pulseaudio-alsa alsa-utils

# Create .xinitrc file with exec dwm
echo "exec dwm" > ~/.xinitrc

# Ask user if they want to install NVIDIA drivers
read -p "Do you want to install NVIDIA drivers? (y/n): " install_nvidia

if [[ $install_nvidia == "y" || $install_nvidia == "Y" ]]; then
    # Install NVIDIA drivers
    sudo pacman -S --noconfirm nvidia nvidia-settings nvidia-utils

    # Check if dkms is installed (in case of using an LTS kernel)
    if pacman -Qs dkms > /dev/null; then
        echo "DKMS detected, rebuilding NVIDIA kernel modules."
        sudo dkms install -m nvidia -v $(pacman -Q nvidia | awk '{print $2}')
    fi

    # Regenerate initramfs
    echo "Regenerating initramfs..."
    sudo mkinitcpio -P

    # Create or update X configuration file for NVIDIA
    echo "Creating /etc/X11/xorg.conf.d/20-nvidia.conf for NVIDIA settings..."
    sudo mkdir -p /etc/X11/xorg.conf.d
    echo -e 'Section "Device"\n  Identifier "NVIDIA GPU"\n  Driver "nvidia"\nEndSection' | sudo tee /etc/X11/xorg.conf.d/20-nvidia.conf

    echo "NVIDIA drivers installed and configured."
else
    echo "NVIDIA drivers not installed."
fi

echo "Setup complete!"