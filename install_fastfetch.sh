#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# Function to fetch the latest release of fastfetch from GitHub
install_fastfetch() {
    # GitHub API URL for the latest release of fastfetch
    GITHUB_API_URL="https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest"

    echo "Fetching the latest release information from GitHub..."

    # Get the download URL for the latest Debian package (.deb) release
    FASTFETCH_URL=$(curl -s $GITHUB_API_URL | grep "browser_download_url.*linux-amd64.deb" | cut -d '"' -f 4)

    # Check if the URL was successfully retrieved
    if [ -z "$FASTFETCH_URL" ]; then
        echo "Failed to retrieve the latest release URL for fastfetch. Exiting."
        exit 1
    fi

    echo "Downloading the latest fastfetch release from: $FASTFETCH_URL"

    # Download the .deb package to /tmp
    wget -q -O /tmp/fastfetch_latest_amd64.deb "$FASTFETCH_URL"

    echo "Installing fastfetch using dpkg..."

    # Install the .deb package
    sudo dpkg -i /tmp/fastfetch_latest_amd64.deb

    echo "Cleaning up..."

    # Remove the downloaded .deb file
    rm /tmp/fastfetch_latest_amd64.deb

    echo "fastfetch has been successfully installed."
}