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
        sudo yum install -y qemu-guest-agent
    elif [[ -f /etc/arch-release ]]; then
        sudo pacman -Syu --noconfirm qemu-guest-agent
    elif [[ -f /etc/SuSE-release ]]; then
        sudo zypper install -y qemu-guest-agent
    else
        echo "Unsupported distribution. Please install qemu-guest-agent manually."
        exit 1
    fi
}

# Ask the user if they want to install qemu-guest-agent
read -p "Do you want to install qemu-guest-agent? (y/n) " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
    if ! check_qemu_guest_agent; then
        install_qemu_guest_agent
        echo "qemu-guest-agent has been installed."
    fi
else
    echo "qemu-guest-agent installation skipped."
fi
