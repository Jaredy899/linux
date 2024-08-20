#!/bin/bash

# Function to install Cockpit and additional modules
install_cockpit() {
    echo "Installing Cockpit and additional modules..."

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
            sudo apt install -y cockpit cockpit-dashboard cockpit-storaged
            sudo systemctl enable --now cockpit
            ;;
        fedora)
            sudo dnf install -y cockpit cockpit-dashboard cockpit-storaged
            sudo systemctl enable --now cockpit
            ;;
        centos|rhel)
            sudo yum install -y cockpit cockpit-dashboard cockpit-storaged
            sudo systemctl enable --now cockpit
            ;;
        rocky|alma)
            sudo dnf install -y cockpit cockpit-dashboard cockpit-storaged
            sudo systemctl enable --now cockpit
            ;;
        opensuse|sles)
            sudo zypper install -y cockpit cockpit-dashboard cockpit-storaged
            sudo systemctl enable --now cockpit
            ;;
        arch)
            sudo pacman -Sy --noconfirm cockpit cockpit-dashboard cockpit-storaged
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

# Run the install function
install_cockpit
