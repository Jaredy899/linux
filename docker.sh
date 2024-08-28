#!/bin/bash

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
        ubuntu|debian)
            echo "Detected Debian/Ubuntu system"
            curl -fsSL https://get.docker.com | sh
            ;;
        fedora)
            echo "Detected Fedora system"
            curl -fsSL https://get.docker.com | sh

            # SELinux adjustment for Docker on Fedora
            echo "Adjusting SELinux for Docker on Fedora..."
            sudo setenforce 0
            sudo sed -i --follow-symlinks 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
            ;;
        centos|rhel|rocky|alma)
            echo "Detected $DISTRO system"
            curl -fsSL https://get.docker.com | sh
            ;;
        arch)
            echo "Detected Arch-based system"
            sudo pacman -Syu --noconfirm
            sudo pacman -S --noconfirm docker docker-compose

            # Enable and start Docker service
            echo "Enabling and starting Docker service..."
            sudo systemctl enable docker
            sudo systemctl start docker

            # Check if Docker service is running
            if ! sudo systemctl is-active --quiet docker; then
                echo "Docker service failed to start on Arch-based system"
                exit 1
            fi
            ;;
        *)
            echo "Unsupported distribution: $DISTRO"
            exit 1
            ;;
    esac

    echo "Docker installation and setup completed."
}

# Function to install and start Portainer
install_portainer() {
    # Ensure Docker is running before installing Portainer
    echo "Ensuring Docker service is running..."
    sudo systemctl start docker
    sudo systemctl enable docker

    # Check if Docker is active
    if ! sudo systemctl is-active --quiet docker; then
        echo "Docker service is not running. Exiting."
        exit 1
    fi

    # Check if the Portainer container exists
    if sudo docker ps -a --format '{{.Names}}' | grep -q "^portainer$"; then
        # If Portainer exists, check its status
        status=$(sudo docker inspect -f '{{.State.Status}}' portainer)
        if [ "$status" == "running" ]; then
            echo "Portainer is already running."
        else
            echo "Portainer is not running (status: $status). Restarting Portainer..."
            sudo docker rm portainer -f
            sudo docker volume rm portainer_data
            start_portainer
        fi
    else
        echo "Portainer container not found. Installing and starting Portainer..."
        start_portainer
    fi
}

# Function to start Portainer
start_portainer() {
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
    for i in {1..30}; do  # Wait up to 30 seconds
        status=$(sudo docker inspect -f '{{.State.Status}}' portainer 2>/dev/null || echo "not found")
        if [ "$status" == "running" ]; then
            echo "Portainer started successfully"
            return
        elif [ "$status" == "not found" ]; then
            echo "Portainer container not found, retrying..."
        else
            echo "Portainer is in status: $status"
        fi
        sleep 1
    done

    echo "Portainer did not start successfully. Checking logs..."
    sudo docker logs portainer || echo "No logs available. Portainer may not have started correctly."
}

install_docker
install_portainer

# Display instructions to manually add user to Docker group
echo "######################################################################################################"
echo "##                                                                                                  ##"  
echo "##  To add your user to the Docker group and apply the changes, please run the following commands:  ##"
echo "##                                                                                                  ##"
echo "##                            sudo usermod -aG docker $USER                                         ##"
echo "##                                     newgrp docker                                                ##"  
echo "##                                                                                                  ##"
echo "##             After running these commands, you can use Docker without sudo.                       ##"
echo "##                                                                                                  ##"  
echo "######################################################################################################"