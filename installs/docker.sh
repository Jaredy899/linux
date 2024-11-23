#!/bin/sh -e

# Source the common script directly from GitHub
. <(curl -s https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/common_script.sh)

# Run the environment check
checkEnv || exit 1

# Function to ask for user confirmation
ask_yes_no() {
    while true; do
        printf "%b" "${CYAN}$1 (y/n) [n]: ${RC}"
        read -r answer
        case $answer in
            [Yy]* ) return 0;;
            [Nn]* | "" ) return 1;;
            * ) printf "%b\n" "${YELLOW}Please answer yes or no.${RC}";;
        esac
    done
}

# Function to install Docker
install_docker() {
    if ! command_exists docker; then
        printf "%b\n" "${YELLOW}Installing Docker...${RC}"
        case "$PACKAGER" in
            pacman)
                noninteractive docker docker-compose
                ;;
            zypper)
                noninteractive docker docker-compose docker-compose-switch
                ;;
            *)
                curl -fsSL https://get.docker.com | "$ESCALATION_TOOL" sh
                ;;
        esac

        # Enable and start Docker service
        "$ESCALATION_TOOL" systemctl enable docker
        "$ESCALATION_TOOL" systemctl start docker
        printf "%b\n" "${GREEN}Docker service enabled and started.${RC}"

        # Check if Docker service is running
        if ! systemctl is-active --quiet docker; then
            printf "%b\n" "${RED}Docker service failed to start.${RC}"
            exit 1
        fi

        # If Fedora, adjust SELinux settings
        if [ "$DISTRO" = "fedora" ]; then
            selinux_status=$(sestatus | grep 'SELinux status:' | awk '{print $3}')
            if [ "$selinux_status" = "enabled" ]; then
                printf "%b\n" "${YELLOW}Adjusting SELinux for Docker on Fedora...${RC}"
                "$ESCALATION_TOOL" setenforce 0
                "$ESCALATION_TOOL" sed -i --follow-symlinks 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
            else
                printf "%b\n" "${GREEN}SELinux is disabled. No adjustment needed.${RC}"
            fi
        fi

        printf "%b\n" "${GREEN}Docker installation and setup completed.${RC}"
    else
        printf "%b\n" "${GREEN}Docker is already installed.${RC}"
    fi
}

# Function to install and start Dockge
install_dockge() {
    if ! "$ESCALATION_TOOL" docker ps -a --format '{{.Names}}' | grep -q "^dockge$"; then
        printf "%b\n" "${YELLOW}Installing and starting Dockge...${RC}"
        
        # Create necessary directories
        "$ESCALATION_TOOL" mkdir -p /opt/dockge
        "$ESCALATION_TOOL" mkdir -p /opt/stacks
        
        # Create docker-compose.yml for Dockge
        cat << EOF | "$ESCALATION_TOOL" tee /opt/dockge/compose.yaml > /dev/null
---
services:
  dockge:
    image: louislam/dockge:latest
    container_name: dockge
    restart: unless-stopped
    ports:
      - 5001:5001
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./data:/app/data
      - /opt/stacks:/opt/stacks
    environment:
      - DOCKGE_STACKS_DIR=/opt/stacks
EOF

        # Start Dockge
        cd /opt/dockge && "$ESCALATION_TOOL" docker compose up -d

        printf "%b\n" "${YELLOW}Waiting for Dockge to start...${RC}"
        for i in $(seq 1 30); do
            if "$ESCALATION_TOOL" docker inspect -f '{{.State.Status}}' dockge 2>/dev/null | grep -q "running"; then
                printf "%b\n" "${GREEN}Dockge started successfully on port 5001.${RC}"
                return
            fi
            sleep 1
        done

        printf "%b\n" "${RED}Dockge did not start successfully. Checking logs...${RC}"
        "$ESCALATION_TOOL" docker logs dockge || printf "%b\n" "${RED}No logs available. Dockge may not have started correctly.${RC}"
    else
        printf "%b\n" "${GREEN}Dockge is already installed.${RC}"
    fi
}

# Function to install and start Portainer
install_portainer() {
    if ! "$ESCALATION_TOOL" docker ps -a --format '{{.Names}}' | grep -q "^portainer$"; then
        printf "%b\n" "${YELLOW}Installing and starting Portainer...${RC}"
        
        # Create directory for Portainer stack
        "$ESCALATION_TOOL" mkdir -p /opt/stacks/portainer
        
        # Create Portainer stack file
        cat << EOF | "$ESCALATION_TOOL" tee /opt/stacks/portainer/compose.yaml > /dev/null
---
services:
  portainer-ce:
    ports:
      - 8000:8000
      - 9443:9443
    container_name: portainer
    restart: always
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    image: portainer/portainer-ce:latest
volumes:
  portainer_data: {}
networks: {}
EOF

        # Start Portainer if Dockge isn't installed
        if ! "$ESCALATION_TOOL" docker ps -a --format '{{.Names}}' | grep -q "^dockge$"; then
            cd /opt/stacks/portainer && "$ESCALATION_TOOL" docker compose up -d
            
            printf "%b\n" "${YELLOW}Waiting for Portainer to start...${RC}"
            for i in $(seq 1 30); do
                if "$ESCALATION_TOOL" docker inspect -f '{{.State.Status}}' portainer 2>/dev/null | grep -q "running"; then
                    printf "%b\n" "${GREEN}Portainer started successfully.${RC}"
                    printf "%b\n" "${YELLOW}Portainer is available at https://$(ip route get 1 | sed -n 's/.*src \([0-9.]\+\).*/\1/p'):9443${RC}"
                    return
                fi
                sleep 1
            done
            
            printf "%b\n" "${RED}Portainer did not start successfully. Checking logs...${RC}"
            "$ESCALATION_TOOL" docker logs portainer || printf "%b\n" "${RED}No logs available. Portainer may not have started correctly.${RC}"
        else
            printf "%b\n" "${GREEN}Portainer stack has been created in /opt/stacks/portainer/compose.yaml${RC}"
            printf "%b\n" "${YELLOW}Please deploy it manually through the Dockge interface at http://$(ip route get 1 | sed -n 's/.*src \([0-9.]\+\).*/\1/p'):5001${RC}"
        fi
    else
        printf "%b\n" "${GREEN}Portainer is already installed.${RC}"
    fi
}

# Main script
install_docker

# Ask about Dockge installation
if ask_yes_no "Would you like to install Dockge (Docker Compose Stack Manager)?"; then
    install_dockge
fi

# Ask about Portainer installation
if ask_yes_no "Would you like to install Portainer?"; then
    install_portainer
fi

# Add current user to the Docker group using the escalation tool
$ESCALATION_TOOL usermod -aG docker $USER

# Display simplified instructions for applying changes
printf "%b\n" "${CYAN}Your user has been added to the Docker group.${RC}"
printf "%b\n" "${CYAN}To apply the changes, you have two options:${RC}"
printf "%b\n"
printf "%b\n" "${CYAN}1. Run the following command to apply changes immediately:${RC}"
printf "%b\n" "${CYAN}   newgrp docker${RC}"
printf "%b\n"
printf "%b\n" "${CYAN}2. Log out and log back in to apply the changes.${RC}"
printf "%b\n"
printf "%b\n" "${CYAN}After applying the changes, you can use Docker without sudo.${RC}"

# Provide an easy-to-copy version of the command
echo -e "\nTo apply changes immediately, copy and run this command:"
echo -e "${CYAN}newgrp docker${RC}\n"
