#!/bin/sh

set -o errexit
set -o nounset
IFS=$(printf '\n\t')

# Function to check if Docker is already installed
check_docker_installed() {
    if command -v docker > /dev/null 2>&1; then
        echo "Docker is already installed. Skipping installation."
        return 0
    else
        return 1
    fi
}

# Function to detect the distribution and install the necessary packages
install_packages() {
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu-based system
        echo "Detected Debian-based system"
        sudo apt update && sudo apt install -y curl
        curl -sSL https://get.docker.com | sh

    elif [ -f /etc/arch-release ]; then
        # Arch-based system
        echo "Detected Arch-based system"
        sudo pacman -Syu --noconfirm
        sudo pacman -S --noconfirm docker docker-compose

    elif [ -f /etc/redhat-release ] || [ -f /etc/SuSE-release ] || ( [ -f /etc/os-release ] && grep -qi "suse" /etc/os-release ); then
        # Red Hat-based system or openSUSE-based system
        echo "Detected Red Hat or openSUSE-based system"
        curl -fsSL https://get.docker.com | sh

    else
        echo "Unsupported distribution"
        exit 1
    fi
}

# Function to start and enable Docker
start_enable_docker() {
    echo "Starting and enabling Docker service..."
    sudo systemctl start docker
    sudo systemctl enable docker
}

# Function to install and start Portainer
install_portainer() {
    if [ "$(sudo docker ps -q -f name=portainer)" ]; then
        echo "Portainer is already running."
    else
        echo "Installing and starting Portainer..."
        sudo docker volume create portainer_data
        sudo docker run -d \
          -p 8000:8000 \
          -p 9000:9000 \
          --name=portainer \
          --restart=always \
          -v /var/run/docker.sock:/var/run/docker.sock \
          -v portainer_data:/data \
          portainer/portainer-ce:latest

        printf 'Waiting for Portainer to start...\n'
        
        TIMEOUT=30
        while [ "$(sudo docker inspect -f '{{.State.Status}}' portainer)" != "running" ]; do
            sleep 1
            TIMEOUT=$((TIMEOUT - 1))
            if [ $TIMEOUT -le 0 ]; then
                echo "Portainer failed to start within the expected time."
                exit 1
            fi
        done

        echo "Portainer started successfully."
    fi
}

# Main script execution
if ! check_docker_installed; then
    install_packages
    start_enable_docker
else
    start_enable_docker
fi

install_portainer

# Display instructions to manually add user to Docker group after Portainer is started
echo "To add your user to the Docker group and apply the changes, please run the following commands:"
echo
echo "  sudo usermod -aG docker $USER"
echo "  newgrp docker"
echo
echo "After running these commands, you can use Docker without sudo."
