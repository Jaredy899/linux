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

# Ensure git is installed
if ! command_exists git; then
    echo "Git is not installed. Installing git..."
    
    checkDistro
    DISTRO="$DTYPE"

    case "$DISTRO" in
        ubuntu|debian)
            echo "Detected Debian/Ubuntu system. Installing git..."
            $ESCALATION_TOOL $PACKAGER update -qq
            $ESCALATION_TOOL $PACKAGER install -y git -qq
            ;;
        fedora|centos|rhel|rocky|alma)
            echo "Detected Fedora/CentOS/RHEL-based system. Installing git..."
            $ESCALATION_TOOL $PACKAGER install -y git -q
            ;;
        arch)
            echo "Detected Arch-based system. Installing git..."
            $ESCALATION_TOOL $PACKAGER -Sy git --noconfirm >/dev/null
            ;;
        *)
            echo "Unsupported distribution: $DISTRO. Please install git manually."
            exit 1
            ;;
    esac
else
    echo "Git is already installed."
fi