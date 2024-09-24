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

# Ensure git is installed
if ! command_exists git; then
    echo "Git is not installed. Installing git..."

    case "$DISTRO" in
        ubuntu|debian)
            echo "Detected Debian/Ubuntu system. Installing git..."
            sudo apt-get update -qq
            sudo apt-get install -y git -qq
            ;;
        fedora|centos|rhel|rocky|alma)
            echo "Detected Fedora/CentOS/RHEL-based system. Installing git..."
            sudo dnf install -y git -q
            ;;
        arch)
            echo "Detected Arch-based system. Installing git..."
            sudo pacman -Sy git --noconfirm >/dev/null
            ;;
        opensuse|suse|opensuse-tumbleweed)
            echo "Detected openSUSE system. Installing git..."
            sudo zypper install -y git
            ;;
        *)
            echo "Unsupported distribution: $DISTRO. Please install git manually."
            exit 1
            ;;
    esac
else
    echo "Git is already installed."
fi
