#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to detect the Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

# Detect the Linux distribution
DISTRO=$(detect_distro)
if [ "$DISTRO" = "unknown" ]; then
    echo "Unable to detect Linux distribution. Exiting."
    exit 1
fi

# Function to install ncdu using the detected package manager
install_ncdu() {
    case "$DISTRO" in
        arch)
            echo "Detected Arch Linux. Installing ncdu..."
            sudo pacman -Syu ncdu --noconfirm
            ;;
        fedora|centos|rhel|rocky|alma)
            echo "Detected Fedora-based system. Installing ncdu..."
            sudo dnf install ncdu -y
            ;;
        debian|ubuntu)
            echo "Detected Debian/Ubuntu. Installing ncdu..."
            sudo apt-get update -y
            sudo apt-get install ncdu -y
            ;;
        *)
            echo "Unsupported distribution: $DISTRO"
            echo "Please install ncdu manually."
            ;;
    esac
}

# Check if ncdu is already installed
if command_exists ncdu; then
    echo "ncdu is already installed."
else
    install_ncdu
fi