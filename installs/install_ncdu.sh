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

# Function to install ncdu using the detected package manager
install_ncdu() {
    checkDistro
    DISTRO="$DTYPE"

    case "$DISTRO" in
        arch)
            echo "Detected Arch Linux. Installing ncdu..."
            $ESCALATION_TOOL $PACKAGER -Syu ncdu --noconfirm
            ;;
        fedora|centos|rhel|rocky|alma)
            echo "Detected Fedora-based system. Installing ncdu..."
            $ESCALATION_TOOL $PACKAGER install ncdu -y
            ;;
        debian|ubuntu)
            echo "Detected Debian/Ubuntu. Installing ncdu..."
            $ESCALATION_TOOL $PACKAGER update -y
            $ESCALATION_TOOL $PACKAGER install ncdu -y
            ;;
        *)
            echo "Unsupported distribution: $DISTRO"
            echo "Please install ncdu manually."
            ;;
    esac
}

# Check if ncdu is already installed
if command_exists ncdu; then
    echo "ncdu is already installed."
else
    install_ncdu
fi