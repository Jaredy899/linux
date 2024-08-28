#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install ncdu based on the detected Linux distribution
install_ncdu() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case $ID in
            arch)
                echo "Detected Arch Linux. Installing ncdu..."
                sudo pacman -Syu ncdu --noconfirm
                ;;
            fedora)
                echo "Detected Fedora. Installing ncdu..."
                sudo dnf install ncdu -y
                ;;
            debian|ubuntu)
                echo "Detected Debian/Ubuntu. Installing ncdu..."
                sudo apt update
                sudo apt install ncdu -y
                ;;
            *)
                echo "Unsupported distribution: $ID"
                echo "Please install ncdu manually."
                ;;
        esac
    else
        echo "Unable to detect Linux distribution."
        echo "Please install ncdu manually."
    fi
}

# Check if ncdu is already installed
if command_exists ncdu; then
    echo "ncdu is already installed."
else
    install_ncdu
fi