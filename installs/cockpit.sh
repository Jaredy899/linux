#!/bin/sh -e

# Source the common script directly from GitHub
. <(curl -s https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/common_script.sh)
. <(curl -s https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/common_service_script.sh)

# Run the environment check
checkEnv || exit 1

# Function to install Cockpit
install_cockpit() {
    if ! command_exists cockpit; then
        printf "%b\n" "${YELLOW}Installing Cockpit...${RC}"
        if [ "$PACKAGER" = "apk" ]; then
            noninteractive cockpit cockpit-ws
        else
            noninteractive cockpit
        fi
        startAndEnableService "cockpit.socket"
        printf "%b\n" "${GREEN}Cockpit service has been started.${RC}"
        if command_exists ufw; then
            "$ESCALATION_TOOL" ufw allow 9090/tcp
            "$ESCALATION_TOOL" ufw reload
            printf "%b\n" "${GREEN}UFW configuration updated to allow Cockpit.${RC}"
        else
            printf "%b\n" "${YELLOW}UFW is not installed. Please ensure port 9090 is open for Cockpit.${RC}"
        fi

        printf "%b\n" "${GREEN}Cockpit installation complete.${RC}"
        printf "%b\n" "${CYAN}You can access Cockpit via https://$(ip route get 1 | sed -n 's/.*src \([0-9.]\+\).*/\1/p'):9090${RC}"
    else
        printf "%b\n" "${GREEN}Cockpit is already installed.${RC}"
    fi
}

# Main script
install_cockpit
