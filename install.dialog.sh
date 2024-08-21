#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install dialog if it isn't already installed
if ! command_exists dialog; then
    echo "dialog is not installed. Installing dialog..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian)
                sudo apt-get update -qq
                sudo apt-get install -y dialog -qq
                ;;
            fedora|centos|rhel)
                sudo dnf install -y dialog -q
                ;;
            arch)
                sudo pacman -Sy dialog --noconfirm >/dev/null
                ;;
            *)
                echo "Unsupported distro. Please install dialog manually."
                exit 1
                ;;
        esac
    else
        echo "Could not detect the operating system. Please install dialog manually."
        exit 1
    fi
else
    echo "dialog is already installed."
fi
