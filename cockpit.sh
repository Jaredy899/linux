#!/bin/sh

# Function to check if Cockpit is installed
is_cockpit_installed() {
    if command -v cockpit > /dev/null 2>&1; then
        echo "Cockpit is already installed."
        return 0
    else
        return 1
    fi
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
            sudo apt update -qq
            sudo apt install -y cockpit -qq
            ;;
        fedora|rocky|alma|centos|rhel)
            sudo dnf install -y cockpit -q
            ;;
        arch)
            sudo pacman -Sy cockpit --noconfirm >/dev/null
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
    if command -v ufw > /dev/null 2>&1; then
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
