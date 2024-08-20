#!/bin/bash

# Function to check if Cockpit is installed
is_cockpit_installed() {
    if command_exists cockpit; then
        echo "Cockpit is already installed."
        return 0
    else
        return 1
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install Cockpit
install_cockpit() {
    echo "Installing Cockpit..."

    # Detect the Linux distribution
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    else
        echo "Unsupported Linux distribution."
        exit 1
    fi

    case "$DISTRO" in
        ubuntu|debian)
            sudo apt update
            sudo apt install -y cockpit
            sudo systemctl enable --now cockpit
            ;;
        fedora|rocky|alma)
            sudo dnf install -y cockpit
            sudo systemctl enable --now cockpit
            ;;
        centos|rhel)
            sudo yum install -y cockpit
            sudo systemctl enable --now cockpit
            ;;
        opensuse|sles)
            sudo zypper install -y cockpit
            sudo systemctl enable --now cockpit
            ;;
        arch)
            sudo pacman -Sy --noconfirm cockpit
            sudo systemctl enable --now cockpit
            ;;
        *)
            echo "Unsupported Linux distribution: $DISTRO"
            exit 1
            ;;
    esac

    echo "Cockpit installation complete."
    echo "You can access Cockpit via https://<your-server-ip>:9090"
}

# Check if Cockpit is already installed
if is_cockpit_installed; then
    echo "No need to install Cockpit."
else
    # Run the install function
    install_cockpit
fi
