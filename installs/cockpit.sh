#!/bin/sh

set -e  # Exit immediately if a command exits with a non-zero status

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to determine the Linux distribution
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

# Function to check if Cockpit is installed
is_cockpit_installed() {
    if command_exists cockpit; then
        echo "Cockpit is already installed."
        return 0
    else
        return 1
    fi
}

# Function to install Cockpit
install_cockpit() {
    echo "Installing Cockpit..."

    case "$DISTRO" in
        ubuntu|debian)
            sudo apt-get update -qq
            sudo apt-get install -y cockpit -qq
            ;;
        fedora|rocky|alma|centos|rhel)
            sudo dnf install -y cockpit -q
            ;;
        arch)
            sudo pacman -Sy cockpit --noconfirm >/dev/null
            ;;
        opensuse|suse|opensuse-tumbleweed)
            sudo zypper install -y cockpit
            ;;
        *)
            echo "Unsupported Linux distribution: $DISTRO"
            exit 1
            ;;
    esac

    # Start the Cockpit service if not already running
    if ! systemctl is-active --quiet cockpit; then
        sudo systemctl enable --now cockpit.socket
        echo "Cockpit service has been started."
    else
        echo "Cockpit service is already running."
    fi

    # Open firewall port for Cockpit (port 9090) if UFW is installed
    if command_exists ufw; then
        sudo ufw allow 9090/tcp
        sudo ufw reload
        echo "UFW configuration updated to allow Cockpit."
    else
        echo "UFW is not installed. Please ensure port 9090 is open for Cockpit."
    fi

    echo "Cockpit installation complete."
    echo "You can access Cockpit via https://<your-server-ip>:9090"
}

# Check if Cockpit is already installed
if is_cockpit_installed; then
    echo "Cockpit is already installed. Skipping installation."
else
    install_cockpit
fi
