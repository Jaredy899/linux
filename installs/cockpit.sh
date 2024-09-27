#!/bin/sh -e

# Source the common script directly from GitHub
. <(curl -s https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/dev/common_script.sh)

# Run the environment check
checkEnv || exit 1

# Function to install Cockpit
install_cockpit() {
    if ! command_exists cockpit; then
        printf "%b\n" "${YELLOW}Installing Cockpit...${RC}"
        case "$PACKAGER" in
            pacman)
                "$ESCALATION_TOOL" "$PACKAGER" -S --needed --noconfirm cockpit
                ;;
            *)
                "$ESCALATION_TOOL" "$PACKAGER" install -y cockpit
                ;;
        esac

        # Start the Cockpit service
        "$ESCALATION_TOOL" systemctl enable --now cockpit.socket
        printf "%b\n" "${GREEN}Cockpit service has been started.${RC}"

        # Open firewall port for Cockpit (port 9090) if UFW is installed
        if command_exists ufw; then
            "$ESCALATION_TOOL" ufw allow 9090/tcp
            "$ESCALATION_TOOL" ufw reload
            printf "%b\n" "${GREEN}UFW configuration updated to allow Cockpit.${RC}"
        else
            printf "%b\n" "${YELLOW}UFW is not installed. Please ensure port 9090 is open for Cockpit.${RC}"
        fi

        printf "%b\n" "${GREEN}Cockpit installation complete.${RC}"
        printf "%b\n" "${CYAN}You can access Cockpit via https://<your-server-ip>:9090${RC}"
    else
        printf "%b\n" "${GREEN}Cockpit is already installed.${RC}"
    fi
}

# Main script
install_cockpit
