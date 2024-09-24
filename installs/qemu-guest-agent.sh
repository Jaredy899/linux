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

# Function to check if qemu-guest-agent is installed
check_qemu_guest_agent() {
    if command_exists qemu-ga; then
        echo "qemu-guest-agent is already installed."
        return 0
    else
        echo "qemu-guest-agent is not installed."
        return 1
    fi
}

# Function to install qemu-guest-agent using the detected package manager
install_qemu_guest_agent() {
    case "$DISTRO" in
        ubuntu|debian)
            echo "Detected Debian/Ubuntu system. Installing qemu-guest-agent..."
            sudo apt-get update -y
            sudo apt-get install -y qemu-guest-agent
            ;;
        fedora|centos|rhel|rocky|alma)
            echo "Detected Fedora/CentOS/RHEL-based system. Installing qemu-guest-agent..."
            sudo dnf install -y qemu-guest-agent
            ;;
        arch)
            echo "Detected Arch-based system. Installing qemu-guest-agent..."
            sudo pacman -Syu --noconfirm qemu-guest-agent
            ;;
        opensuse|suse|opensuse-tumbleweed)
            echo "Detected openSUSE system. Installing qemu-guest-agent..."
            sudo zypper refresh
            sudo zypper install -y qemu-guest-agent
            ;;
        *)
            echo "Unsupported distribution: $DISTRO. Please install qemu-guest-agent manually."
            exit 1
            ;;
    esac
}

# Function to start the qemu-guest-agent service
start_qemu_guest_agent_service() {
    if ! systemctl is-active --quiet qemu-guest-agent; then
        sudo systemctl enable --now qemu-guest-agent
        echo "qemu-guest-agent service has been started."
    else
        echo "qemu-guest-agent service is already running."
    fi
}

# Check if qemu-guest-agent is installed and install it if not
if ! check_qemu_guest_agent; then
    install_qemu_guest_agent
    echo "qemu-guest-agent has been installed."
fi

# Ensure the qemu-guest-agent service is started
start_qemu_guest_agent_service
