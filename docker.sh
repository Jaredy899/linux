#!/bin/sh

set -o errexit
set -o nounset
IFS=$(printf '\n\t')

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
        sudo systemctl start docker
        sudo systemctl enable docker

    elif [ -f /etc/redhat-release ]; then
        # CentOS/Fedora-based system
        echo "Detected Red Hat-based system"
        curl -fsSL https://get.docker.com | sh
        sudo systemctl start docker
        sudo systemctl enable docker

    elif [ -f /etc/os-release ] && grep -qi "suse" /etc/os-release; then
        # openSUSE-based system
        echo "Detected openSUSE-based system"
        sudo zypper refresh
        sudo zypper install -y docker docker-compose
        sudo systemctl start docker
        sudo systemctl enable docker

    else
        echo "Unsupported distribution"
        exit 1
    fi
}

# Function to install and start Portainer
install_portainer() {
    if [ "$(sudo docker ps -q -f name=portainer)" ]; then
        echo "Portainer is already running"
    else
        sudo docker volume create portainer_data
        sudo docker run -d \
          -p 8000:8000 \
          -p 9000:9000 \
          --name=portainer \
          --restart=always \
          -v /var/run/docker.sock:/var/run/docker.sock \
          -v portainer_data:/data \
          portainer/portainer-ce:latest

        printf 'Waiting for Portainer to start...\n\n'
        until [ "$(sudo docker inspect -f '{{.State.Status}}' portainer)" = "running" ]; do
            sleep 1
        done

        printf '\nPortainer started successfully\n\n'
    fi
}

install_packages

# Install Portainer with sudo to avoid permission issues
install_portainer

# Display instructions to manually add user to Docker group after Portainer is started
echo "To add your user to the Docker group and apply the changes, please run the following commands:"
echo
echo "  sudo usermod -aG docker $USER"
echo "  newgrp docker"
echo
echo "After running these commands, you can use Docker without sudo."
