#!/bin/bash

# Function to check if qemu-guest-agent is installed
check_qemu_guest_agent() {
    if command -v qemu-ga > /dev/null 2>&1; then
        echo "qemu-guest-agent is already installed."
        return 0
    else
        echo "qemu-guest-agent is not installed."
        return 1
    fi
}

# Function to install qemu-guest-agent based on the package manager
install_qemu_guest_agent() {
    if [[ -f /etc/debian_version ]]; then
        sudo apt-get update
        sudo apt-get install -y qemu-guest-agent
    elif [[ -f /etc/redhat-release ]]; then
        sudo dnf install -y qemu-guest-agent
    elif [[ -f /etc/arch-release ]]; then
        sudo pacman -Syu --noconfirm qemu-guest-agent
    else
        echo "Unsupported distribution. Please install qemu-guest-agent manually."
        exit 1
    fi
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
