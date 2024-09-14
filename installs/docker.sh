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
                selinux_status=$(sestatus | grep 'SELinux status:' | awk '{print $3}')
                if [ "$selinux_status" = "enabled" ]; then
                    echo "Adjusting SELinux for Docker on Fedora..."
                    sudo setenforce 0
                    sudo sed -i --follow-symlinks 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
                else
                    echo "SELinux is disabled. No adjustment needed."
                fi
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
                echo "Docker service failed to start on Arch-based system"
                exit 1
            fi
            ;;
        opensuse|suse)
            echo "Detected openSUSE system"
            sudo zypper refresh
            sudo zypper install -y docker

            # Enable and start Docker service
            echo "Enabling and starting Docker service..."
            sudo systemctl enable --now docker

            # Check if Docker service is running
            if ! systemctl is-active --quiet docker; then
                echo "Docker service failed to start on openSUSE system"
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
    if ! systemctl is-active --quiet docker; then
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
echo "##                            sudo usermod -aG docker \$USER                                         ##"
echo "##                                     newgrp docker                                                ##"  
echo "##                                                                                                  ##"
echo "##             After running these commands, you can use Docker without sudo.                       ##"
echo "##                                                                                                  ##"  
echo "######################################################################################################"
