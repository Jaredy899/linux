#!/bin/bash

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

# Function to check if qemu-guest-agent is installed
check_qemu_guest_agent() {
    if command_exists qemu-ga; then
        echo "qemu-guest-agent is already installed."
        return 0
    else
        echo "qemu-guest-agent is not installed."
        return 1
    fi
}

# Function to install qemu-guest-agent using the detected package manager
install_qemu_guest_agent() {
    checkDistro
    DISTRO="$DTYPE"

    case "$DISTRO" in
        ubuntu|debian)
            echo "Detected Debian/Ubuntu system. Installing qemu-guest-agent..."
            $ESCALATION_TOOL $PACKAGER update -y
            $ESCALATION_TOOL $PACKAGER install -y qemu-guest-agent
            ;;
        fedora|centos|rhel|rocky|alma)
            echo "Detected Fedora/CentOS/RHEL-based system. Installing qemu-guest-agent..."
            $ESCALATION_TOOL $PACKAGER install -y qemu-guest-agent
            ;;
        arch)
            echo "Detected Arch-based system. Installing qemu-guest-agent..."
            $ESCALATION_TOOL $PACKAGER -Syu --noconfirm qemu-guest-agent
            ;;
        *)
            echo "Unsupported distribution: $DISTRO. Please install qemu-guest-agent manually."
            exit 1
            ;;
    esac
}

# Function to start the qemu-guest-agent service
start_qemu_guest_agent_service() {
    if ! systemctl is-active --quiet qemu-guest-agent; then
        $ESCALATION_TOOL systemctl enable --now qemu-guest-agent
        echo "qemu-guest-agent service has been started."
    else
        echo "qemu-guest-agent service is already running."
    fi
}

# Check if qemu-guest-agent is installed and install it if not
if ! check_qemu_guest_agent; then
    install_qemu_guest_agent
    echo "qemu-guest-agent has been installed."
fi

# Ensure the qemu-guest-agent service is started
start_qemu_guest_agent_service