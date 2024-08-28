#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status
set -x  # Print each command before executing it (useful for debugging)

# Function to fetch the latest release of fastfetch from GitHub
install_fastfetch() {
    # GitHub API URL for the latest release of fastfetch
    GITHUB_API_URL="https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest"

    echo "Fetching the latest release information from GitHub..."

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

    echo "Detected architecture: $ARCH. Looking for $ARCH_DEB package."

    # Get the download URL for the latest Debian package (.deb) release for the detected architecture
    FASTFETCH_URL=$(curl -s $GITHUB_API_URL | grep "browser_download_url.*$ARCH_DEB" | cut -d '"' -f 4)

    # Check if the URL was successfully retrieved
    if [ -z "$FASTFETCH_URL" ]; then
        echo "Failed to retrieve the latest release URL for fastfetch for architecture $ARCH. Exiting."
        exit 1
    fi

    echo "Downloading the latest fastfetch release from: $FASTFETCH_URL"

    # Download the .deb package to /tmp using curl with retry
    curl -L --retry 3 -o /tmp/fastfetch_latest_$ARCH.deb "$FASTFETCH_URL"

    # Check if the download was successful
    if [ ! -s /tmp/fastfetch_latest_$ARCH.deb ]; then
        echo "Downloaded file is empty or corrupted. Exiting."
        rm -f /tmp/fastfetch_latest_$ARCH.deb  # Remove corrupted file
        exit 1
    fi

    echo "Verifying the downloaded package..."

    # Verify the downloaded package
    if ! dpkg-deb --info /tmp/fastfetch_latest_$ARCH.deb > /dev/null 2>&1; then
        echo "The .deb file is corrupted or invalid. Exiting."
        rm -f /tmp/fastfetch_latest_$ARCH.deb  # Remove corrupted file
        exit 1
    fi

    echo "Installing fastfetch using dpkg..."

    # Install the .deb package
    sudo dpkg -i /tmp/fastfetch_latest_$ARCH.deb || sudo apt-get install -f -y

    echo "Cleaning up..."

    # Remove the downloaded .deb file
    rm /tmp/fastfetch_latest_$ARCH.deb

    echo "fastfetch has been successfully installed."
}

# Run the function
install_fastfetch