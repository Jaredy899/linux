#!/bin/sh

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
            ;;
        fedora|rocky|alma)
            sudo dnf install -y cockpit
            ;;
        centos|rhel)
            sudo yum install -y cockpit
            ;;
        opensuse|sles)
            sudo zypper install -y cockpit
            ;;
        arch)
            sudo pacman -Sy --noconfirm cockpit
            ;;
        *)
            echo "Unsupported Linux distribution: $DISTRO"
            exit 1
            ;;
    esac

    sudo systemctl start cockpit
    sudo systemctl enable cockpit

    # Configure UFW to allow Cockpit through the firewall
    if command_exists ufw; then
        sudo ufw allow 9090/tcp
        sudo ufw reload
        echo "UFW configuration updated to allow Cockpit."
    else
        echo "UFW is not installed or not found. Please ensure port 9090 is open for Cockpit."
    fi

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
