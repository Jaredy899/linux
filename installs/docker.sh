#!/bin/sh -e

# Source the common scripts directly from GitHub
. <(curl -s https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/common_script.sh)
. <(curl -s https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/common_service_script.sh)

# Run the environment check
checkEnv || exit 1
checkDistro

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
            apk)
                "$ESCALATION_TOOL" apk add --no-cache --update-cache \
                    --repository http://dl-cdn.alpinelinux.org/alpine/latest-stable/community \
                    docker docker-compose
                ;;
            dnf)
                if [ "$DTYPE" = "rocky" ] || [ "$DTYPE" = "almalinux" ]; then
                    "$ESCALATION_TOOL" dnf remove -y docker docker-client docker-client-latest \
                        docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine
                    "$ESCALATION_TOOL" dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
                    noninteractive docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
                else
                    curl -fsSL https://get.docker.com | "$ESCALATION_TOOL" sh
                fi
                ;;
            *)
                curl -fsSL https://get.docker.com | "$ESCALATION_TOOL" sh
                ;;
        esac

        # Enable and start Docker service
        startAndEnableService docker
        
        # Check if Docker service is running
        if ! isServiceActive docker; then
            printf "%b\n" "${RED}Docker service failed to start.${RC}"
            exit 1
        fi
        printf "%b\n" "${GREEN}Docker service enabled and started.${RC}"

        # Handle Fedora SELinux
        if [ "$DTYPE" = "fedora" ] && sestatus 2>/dev/null | grep -q 'SELinux status:\s*enabled'; then
            printf "%b\n" "${YELLOW}Adjusting SELinux for Docker on Fedora...${RC}"
            "$ESCALATION_TOOL" setenforce 0
            "$ESCALATION_TOOL" sed -i --follow-symlinks 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
        fi

        printf "%b\n" "${GREEN}Docker installation and setup completed.${RC}"
    else
        printf "%b\n" "${GREEN}Docker is already installed.${RC}"
    fi
}

# Function to create and start a Docker compose stack
create_compose_stack() {
    local stack_name="$1"
    local stack_dir="$2"
    local compose_content="$3"
    
    if ! "$ESCALATION_TOOL" docker ps -a --format '{{.Names}}' | grep -q "^${stack_name}$"; then
        printf "%b\n" "${YELLOW}Installing and starting ${stack_name}...${RC}"
        
        # Create directory for stack
        "$ESCALATION_TOOL" mkdir -p "$stack_dir"
        
        # Create compose file
        printf "%s" "$compose_content" | "$ESCALATION_TOOL" tee "${stack_dir}/compose.yaml" > /dev/null

        # Start stack if Dockge isn't installed, otherwise just create the file
        if ! "$ESCALATION_TOOL" docker ps -a --format '{{.Names}}' | grep -q "^dockge$"; then
            cd "$stack_dir" && "$ESCALATION_TOOL" docker compose up -d
            
            printf "%b\n" "${YELLOW}Waiting for ${stack_name} to start...${RC}"
            for _ in $(seq 1 30); do
                if "$ESCALATION_TOOL" docker inspect -f '{{.State.Status}}' "$stack_name" 2>/dev/null | grep -q "running"; then
                    printf "%b\n" "${GREEN}${stack_name} started successfully.${RC}"
                    return 0
                fi
                sleep 1
            done
            
            printf "%b\n" "${RED}${stack_name} did not start successfully. Checking logs...${RC}"
            "$ESCALATION_TOOL" docker logs "$stack_name" || printf "%b\n" "${RED}No logs available. ${stack_name} may not have started correctly.${RC}"
        else
            printf "%b\n" "${GREEN}${stack_name} stack has been created in ${stack_dir}/compose.yaml${RC}"
            printf "%b\n" "${YELLOW}Please deploy it manually through the Dockge interface at http://$(ip route get 1 | sed -n 's/.*src \([0-9.]\+\).*/\1/p'):5001${RC}"
        fi
    else
        printf "%b\n" "${GREEN}${stack_name} is already installed.${RC}"
    fi
}

# Function to install and start Dockge
install_dockge() {
    local dockge_compose="---
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
      - DOCKGE_STACKS_DIR=/opt/stacks"

    create_compose_stack "dockge" "/opt/dockge" "$dockge_compose"
}

# Function to install and start Portainer
install_portainer() {
    local portainer_compose="---
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
networks: {}"

    create_compose_stack "portainer" "/opt/stacks/portainer" "$portainer_compose"
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
