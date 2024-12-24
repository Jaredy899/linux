#!/bin/sh -e

# Source common scripts
eval "$(curl -s https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/common_script.sh)"
eval "$(curl -s https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/common_service_script.sh)"

install_networkmanager() {
    printf "%b\n" "${CYAN}Installing NetworkManager...${RC}"
    
    case "$PACKAGER" in
        pacman|apk|eopkg)
            noninteractive networkmanager
            ;;
        apt-get|nala)
            noninteractive network-manager
            ;;
        dnf|zypper|xbps-install)
            noninteractive NetworkManager
            ;;
        *)
            printf "%b\n" "${RED}Unsupported package manager: $PACKAGER${RC}"
            exit 1
            ;;
    esac

    # Special handling for antiX Linux
    if [ "$DTYPE" = "antix" ] || grep -qi "antix" /etc/os-release 2>/dev/null; then
        printf "%b\n" "${CYAN}Detected antiX Linux - configuring rc.local...${RC}"
        
        # Check if rc.local exists, create if it doesn't
        if [ ! -f /etc/rc.local ]; then
            printf "%b\n" "${YELLOW}Creating /etc/rc.local...${RC}"
            echo "#!/bin/sh" | "$ESCALATION_TOOL" tee /etc/rc.local
            "$ESCALATION_TOOL" chmod +x /etc/rc.local
        fi

        # Add NetworkManager to rc.local if not already present
        if ! grep -q "NetworkManager" /etc/rc.local; then
            printf "%b\n" "${CYAN}Adding NetworkManager to rc.local...${RC}"
            "$ESCALATION_TOOL" sed -i '/^exit 0/i NetworkManager start' /etc/rc.local
        fi
    fi

    # Enable and start NetworkManager service
    printf "%b\n" "${CYAN}Enabling and starting NetworkManager service...${RC}"
    case "$PACKAGER" in
        apk)
            # Alpine Linux uses lowercase service name
            startAndEnableService networkmanager
            ;;
        *)
            startAndEnableService NetworkManager
            ;;
    esac

    # Start immediately for antiX
    if [ "$DTYPE" = "antix" ] || grep -qi "antix" /etc/os-release 2>/dev/null; then
        printf "%b\n" "${CYAN}Starting NetworkManager immediately...${RC}"
        "$ESCALATION_TOOL" NetworkManager start
    fi

    # Verify if service is running
    if [ "$PACKAGER" = "apk" ]; then
        if isServiceActive networkmanager; then
            printf "%b\n" "${GREEN}NetworkManager has been successfully installed and started!${RC}"
        else
            printf "%b\n" "${RED}Failed to start NetworkManager service${RC}"
            exit 1
        fi
    else
        if isServiceActive NetworkManager; then
            printf "%b\n" "${GREEN}NetworkManager has been successfully installed and started!${RC}"
        else
            printf "%b\n" "${RED}Failed to start NetworkManager service${RC}"
            exit 1
        fi
    fi
}

main() {
    # Check environment and requirements
    checkEnv

    # Install NetworkManager
    install_networkmanager
}

# Run main function
main 
