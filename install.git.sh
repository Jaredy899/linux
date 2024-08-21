#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Ensure git is installed
if ! command_exists git; then
    echo "Git is not installed. Installing git..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian)
                sudo apt-get update -qq
                sudo apt-get install -y git -qq
                ;;
            fedora|centos|rhel)
                sudo dnf install -y git -q
                ;;
            arch)
                sudo pacman -Sy git --noconfirm >/dev/null
                ;;
            *)
                echo "Unsupported distro. Please install git manually."
                exit 1
                ;;
        esac
    else
        echo "Could not detect the operating system. Please install git manually."
        exit 1
    fi
else
    echo "Git is already installed."
fi
