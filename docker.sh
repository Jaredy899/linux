#!/bin/sh

set -o errexit
set -o nounset
IFS=$(printf '\n\t')

# Function to detect the distribution and install Docker
install_docker() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    else
        echo "Unsupported distribution"
        exit 1
    fi

    case "$DISTRO" in
        ubuntu|debian|fedora|centos|rhel|rocky|alma)
            echo "Detected $DISTRO system"
            curl -fsSL https://get.docker.com | sh
            ;;
        arch)
            echo "Detected Arch-based system"
            sudo pacman -Syu --noconfirm
            sudo pacman -S --noconfirm docker docker-compose
            ;;
        *)
            echo "Unsupported distribution: $DISTRO"
            exit 1
            ;;
    esac

    sudo systemctl start docker
    sudo systemctl enable docker
}

# Function to install and start Portainer
install_portainer() {
    if ! sudo docker ps -q -f name=portainer > /dev/null; then
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

        echo "Waiting for Portainer to start..."
        until [ "$(sudo docker inspect -f '{{.State.Status}}' portainer)" = "running" ]; do
            sleep 1
        done
        echo "Portainer started successfully"
    else
        echo "Portainer is already running"
    fi
}

install_docker
install_portainer

# Display instructions to manually add user to Docker group
echo "To add your user to the Docker group and apply the changes, please run the following commands:"
echo "  sudo usermod -aG docker $USER"
echo "  newgrp docker"
echo "After running these commands, press Enter to return to the dialog box."

# Pause execution to wait for the user to apply the group change
read -p "Press Enter after you have applied 'newgrp docker' to continue..."

# Here you can place the code to return to the dialog box or any further steps
# For example, this could be a call to your dialog menu script or any continuation logic
# ./dialog_linux.sh
