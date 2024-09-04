#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# GitHub URL base for the necessary configuration files
GITHUB_BASE_URL="https://raw.githubusercontent.com/Jaredy899/linux/main"

# Source the common.sh script
COMMON_SCRIPT_URL="${GITHUB_BASE_URL}/common.sh"

# Download and source the common.sh script if it's not already present
if [ ! -f "common.sh" ]; then
    echo "Downloading common.sh..."
    curl -s -O "${COMMON_SCRIPT_URL}"
fi
source "./common.sh"

# Run environment checks using common.sh
checkEnv

# Function to fetch the latest release of fastfetch from GitHub
install_fastfetch() {
    echo "Installing fastfetch..."

    # GitHub API URL for the latest release of fastfetch
    GITHUB_API_URL="https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest"

    # Detect the system architecture
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)
            ARCH_DEB="linux-amd64.deb"
            ;;
        aarch64)
            ARCH_DEB="linux-aarch64.deb"
            ;;
        armv7l)
            ARCH_DEB="linux-armv7l.deb"
            ;;
        riscv64)
            ARCH_DEB="linux-riscv64.deb"
            ;;
        *)
            echo "Unsupported architecture: $ARCH. Exiting."
            exit 1
            ;;
    esac

    # Get the download URL for the latest Debian package (.deb) release for the detected architecture
    FASTFETCH_URL=$(curl -s $GITHUB_API_URL | grep "browser_download_url.*$ARCH_DEB" | cut -d '"' -f 4)

    # Check if the URL was successfully retrieved
    if [ -z "$FASTFETCH_URL" ]; then
        echo "Failed to retrieve the latest release URL for fastfetch. Exiting."
        exit 1
    fi

    # Download the .deb package to /tmp using curl with retry
    curl -s -L --retry 3 -o /tmp/fastfetch_latest_$ARCH.deb "$FASTFETCH_URL"

    # Check if the download was successful
    if [ ! -s /tmp/fastfetch_latest_$ARCH.deb ]; then
        echo "Downloaded file is empty or corrupted. Exiting."
        rm -f /tmp/fastfetch_latest_$ARCH.deb  # Remove corrupted file
        exit 1
    fi

    # Verify the downloaded package
    if ! dpkg-deb --info /tmp/fastfetch_latest_$ARCH.deb > /dev/null 2>&1; then
        echo "The .deb file is corrupted or invalid. Exiting."
        rm -f /tmp/fastfetch_latest_$ARCH.deb  # Remove corrupted file
        exit 1
    fi

    # Install the .deb package using the escalation tool from common.sh
    $ESCALATION_TOOL dpkg -i /tmp/fastfetch_latest_$ARCH.deb || $ESCALATION_TOOL apt-get install -f -y

    # Remove the downloaded .deb file
    rm /tmp/fastfetch_latest_$ARCH.deb

    echo "fastfetch has been successfully installed."
}

# Run the function
install_fastfetch