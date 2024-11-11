#!/bin/sh -e

# Source the common script directly from GitHub
. <(curl -s https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/common_script.sh)

# Run the environment check
checkEnv || exit 1

# Function to install Docker
install_docker() {
    if ! command_exists docker; then
        printf "%b\n" "${YELLOW}Installing Docker...${RC}"
        case "$PACKAGER" in
            apk)
                # Update package index and add community repository
                "$ESCALATION_TOOL" apk update
                "$ESCALATION_TOOL" apk add --no-cache docker docker-compose-plugin

                # Enable and start Docker service
                "$ESCALATION_TOOL" rc-update add docker boot
                "$ESCALATION_TOOL" service docker start

                # Wait for Docker to start
                printf "%b\n" "${YELLOW}Waiting for Docker service to start...${RC}"
                sleep 5
                ;;
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

        if command -v systemctl >/dev/null 2>&1; then
            # SystemD systems
            "$ESCALATION_TOOL" systemctl enable docker
            "$ESCALATION_TOOL" systemctl start docker
            printf "%b\n" "${GREEN}Docker service enabled and started.${RC}"

            # Check if Docker service is running
            if ! systemctl is-active --quiet docker; then
                printf "%b\n" "${RED}Docker service failed to start.${RC}"
                exit 1
            fi
        else
            # OpenRC systems (Alpine)
            if ! "$ESCALATION_TOOL" service docker status >/dev/null 2>&1; then
                printf "%b\n" "${RED}Docker service failed to start.${RC}"
                exit 1
            fi
        fi

        printf "%b\n" "${GREEN}Docker installation and setup completed.${RC}"
    else
        printf "%b\n" "${GREEN}Docker is already installed.${RC}"
    fi
}

# Function to install and start Portainer
install_portainer() {
    if ! "$ESCALATION_TOOL" docker ps -a --format '{{.Names}}' | grep -q "^portainer$"; then
        printf "%b\n" "${YELLOW}Installing and starting Portainer...${RC}"
        "$ESCALATION_TOOL" docker volume create portainer_data
        "$ESCALATION_TOOL" docker run -d \
            -p 8000:8000 \
            -p 9443:9443 \
            --name=portainer \
            --restart=always \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v portainer_data:/data \
            portainer/portainer-ce:latest

        printf "%b\n" "${YELLOW}Waiting for Portainer to start...${RC}"
        for i in $(seq 1 30); do
            if "$ESCALATION_TOOL" docker inspect -f '{{.State.Status}}' portainer 2>/dev/null | grep -q "running"; then
                printf "%b\n" "${GREEN}Portainer started successfully.${RC}"
                return
            fi
            sleep 1
        done

        printf "%b\n" "${RED}Portainer did not start successfully. Checking logs...${RC}"
        "$ESCALATION_TOOL" docker logs portainer || printf "%b\n" "${RED}No logs available. Portainer may not have started correctly.${RC}"
    else
        printf "%b\n" "${GREEN}Portainer is already installed.${RC}"
    fi
}

# Main script
install_docker
install_portainer

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
