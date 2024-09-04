#!/bin/bash

set -o errexit
set -o nounset
IFS=$(printf '\n\t')

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

# Function to install Docker
install_docker() {
    case "$DISTRO" in
        ubuntu|debian|fedora|centos|rhel|rocky|alma)
            echo "Detected $DISTRO system"
            curl -fsSL https://get.docker.com | sudo sh
            
            # If Fedora, adjust SELinux settings
            if [ "$DISTRO" = "fedora" ]; then
                echo "Adjusting SELinux for Docker on Fedora..."
                sudo setenforce 0
                sudo sed -i --follow-symlinks 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
            fi
            ;;
        arch)
            echo "Detected Arch-based system"
            sudo pacman -Syu --noconfirm
            sudo pacman -S --noconfirm docker docker-compose

            # Enable and start Docker service
            echo "Enabling and starting Docker service..."
            sudo systemctl enable --now docker

            # Check if Docker service is running
            if ! systemctl is-active --quiet docker; then
                echo "Docker service failed to start on Arch-based system​⬤