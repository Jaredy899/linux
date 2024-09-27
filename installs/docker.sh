#!/bin/sh -e

# Source the common script directly from GitHub
. <(curl -s https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/dev/common_script.sh)

# Run the environment check
checkEnv || exit 1

# Function to install Docker
install_docker() {
    if ! command_exists docker; then
        printf "%b\n" "${YELLOW}Installing Docker...${RC}"
        case "$PACKAGER" in
            pacman)
                "$ESCALATION_TOOL" "$PACKAGER" -Syu --noconfirm
                "$ESCALATION_TOOL" "$PACKAGER" -S --needed --noconfirm docker docker-compose
                ;;
            zypper)
                "$ESCALATION_TOOL" "$PACKAGER" refresh
                "$ESCALATION_TOOL" "$PACKAGER" install -y docker
                ;;
            *)
                curl -fsSL https://get.docker.com | "$ESCALATION_TOOL" sh
                ;;
        esac

        # Enable and start Docker service
        "$ESCALATION_TOOL" systemctl enable --now docker
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

# Function to install and start Portainer
install_portainer() {
    if ! "$ESCALATION_TOOL" docker ps -a --format '{{.Names}}' | grep -q "^portainer$"; then
        printf "%b\n" "${YELLOW}Installing and starting Portainer...${RC}"
        "$ESCALATION_TOOL" docker volume create portainer_data
        "$ESCALATION_TOOL" docker run -d \
            -p 8000:8000 \
            -p 9000:9000 \
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

# Display instructions to manually add user to Docker group
printf "%b\n" "${CYAN}######################################################################################################${RC}"
printf "%b\n" "${CYAN}##                                                                                                  ##${RC}"
printf "%b\n" "${CYAN}##  To add your user to the Docker group and apply the changes, please run the following commands:  ##${RC}"
printf "%b\n" "${CYAN}##                                                                                                  ##${RC}"
printf "%b\n" "${CYAN}##                            sudo usermod -aG docker \$USER                                         ##${RC}"
printf "%b\n" "${CYAN}##                                     newgrp docker                                                ##${RC}"
printf "%b\n" "${CYAN}##                                                                                                  ##${RC}"
printf "%b\n" "${CYAN}##             After running these commands, you can use Docker without sudo.                       ##${RC}"
printf "%b\n" "${CYAN}##                                                                                                  ##${RC}"
printf "%b\n" "${CYAN}######################################################################################################${RC}"
