#!/bin/bash

set -o errexit
set -o nounset
IFS=$(printf '\n\t')

# Source the common.sh script
GITHUB_BASE_URL="https://raw.githubusercontent.com/Jaredy899/linux/main"
COMMON_SCRIPT_URL="${GITHUB_BASE_URL}/common.sh"

# Download and source the common.sh script if it's not already present
if [ ! -f "common.sh" ]; then
    echo "Downloading common.sh..."
    curl -s -O "${COMMON_SCRIPT_URL}"
fi
source ./common.sh

# Run environment checks using common.sh
checkEnv

# Function to install Docker using common.sh
install_docker() {
    # Detect the Linux distribution using common.sh
    checkDistro
    DISTRO="$DTYPE"

    case "$DISTRO" in
        ubuntu|debian|fedora|centos|rhel|rocky|alma)
            echo "Detected $DISTRO system"
            curl -fsSL https://get.docker.com | $ESCALATION_TOOL sh
            
            # If Fedora, adjust SELinux settings
            if [ "$DISTRO" = "fedora" ]; then
                echo "Adjusting SELinux for Docker on Fedora..."
                $ESCALATION_TOOL setenforce 0
                $ESCALATION_TOOL sed -i --follow-symlinks 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
            fi
            ;;
        arch)
            echo "Detected Arch-based system"
            $ESCALATION_TOOL $PACKAGER -Syu --noconfirm
            $ESCALATION_TOOL $PACKAGER -S --noconfirm docker docker-compose

            # Enable and start Docker service
            echo "Enabling and starting Docker service..."
            $ESCALATION_TOOL systemctl enable --now docker

            # Check if Docker service is running
            if ! systemctl is-active --quiet docker; then
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
    $ESCALATION_TOOL systemctl start docker
    $ESCALATION_TOOL systemctl enable docker

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
    $ESCALATION_TOOL docker volume create portainer_data
    $ESCALATION_TOOL docker run -d \
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