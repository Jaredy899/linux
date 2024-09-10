#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

reboot_required=false

echo "-------------------------------------------------------------------------"
echo "                    Installing Graphics Drivers"
echo "-------------------------------------------------------------------------"

# Detect GPU Type
gpu_type=$(lspci | grep -E "VGA|3D")

# OS Detection
if [ -f /etc/arch-release ]; then
    OS="arch"
elif [ -f /etc/debian_version ]; then
    OS="debian"
elif [ -f /etc/fedora-release ]; then
    OS="fedora"
else
    echo "Unsupported OS"
    exit 1
fi

# Graphics Drivers installation based on OS and GPU type
if echo "${gpu_type}" | grep -E "NVIDIA|GeForce"; then
    echo "Detected NVIDIA GPU"
    if [ "$OS" == "arch" ]; then
        echo "Installing NVIDIA drivers: nvidia"
        sudo pacman -S --noconfirm --needed nvidia nvidia-settings
        reboot_required=true
    elif [ "$OS" == "debian" ]; then
        echo "Installing NVIDIA drivers"
        sudo apt install -y nvidia-driver firmware-misc-nonfree
        reboot_required=true
    elif [ "$OS" == "fedora" ]; then
        echo "Installing NVIDIA drivers"
        sudo dnf install -y akmod-nvidia
        reboot_required=true
    fi
elif echo "${gpu_type}" | grep 'VGA' | grep -E "Radeon|AMD"; then
    echo "Detected AMD GPU"
    if [ "$OS" == "arch" ]; then
        echo "Installing AMD drivers: xf86-video-amdgpu"
        sudo pacman -S --noconfirm --needed xf86-video-amdgpu
        reboot_required=true
    elif [ "$OS" == "debian" ]; then
        echo "Installing AMD drivers"
        sudo apt install -y firmware-amd-graphics
        reboot_required=true
    elif [ "$OS" == "fedora" ]; then
        echo "Installing AMD drivers"
        sudo dnf install -y xorg-x11-drv-amdgpu
        reboot_required=true
    fi
elif echo "${gpu_type}" | grep -E "Intel"; then
    echo "Detected Intel GPU"
    if [ "$OS" == "arch" ]; then
        echo "Installing Intel drivers"
        sudo pacman -S --noconfirm --needed libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-utils lib32-mesa
        reboot_required=true
    elif [ "$OS" == "debian" ]; then
        echo "Installing Intel drivers"
        sudo apt install -y intel-media-va-driver mesa-va-drivers mesa-vulkan-drivers
        reboot_required=true
    elif [ "$OS" == "fedora" ]; then
        echo "Installing Intel drivers"
        sudo dnf install -y intel-media-driver mesa-vulkan-drivers
        reboot_required=true
    fi
else
    echo "No supported GPU found"
fi

echo "-------------------------------------------------------------------------"
echo "                     Installing Network Manager                          "
echo "-------------------------------------------------------------------------"

# Install and enable NetworkManager
if [ "$OS" == "arch" ]; then
    sudo pacman -S --noconfirm --needed networkmanager
    sudo systemctl enable --now NetworkManager
elif [ "$OS" == "debian" ]; then
    sudo apt install -y network-manager
    sudo systemctl enable --now NetworkManager
elif [ "$OS" == "fedora" ]; then
    sudo dnf install -y NetworkManager
    sudo systemctl enable --now NetworkManager
fi

echo "-------------------------------------------------------------------------"
echo "                       Installing Applications                           "
echo "-------------------------------------------------------------------------"

# Function to detect the system architecture
detect_arch() {
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)
            echo "linux-amd64.deb"
            ;;
        aarch64)
            echo "linux-aarch64.deb"
            ;;
        armv7l)
            echo "linux-armv7l.deb"
            ;;
        riscv64)
            echo "linux-riscv64.deb"
            ;;
        *)
            echo "unsupported"
            ;;
    esac
}

# Function to fetch the latest release of fastfetch from GitHub
install_fastfetch() {
    echo "Installing fastfetch..."

    # GitHub API URL for the latest release of fastfetch
    GITHUB_API_URL="https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest"

    # Detect the system architecture
    ARCH_DEB=$(detect_arch)
    if [ "$ARCH_DEB" = "unsupported" ]; then
        echo "Unsupported architecture. Exiting."
        exit 1
    fi

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

    # Install the .deb package
    sudo dpkg -i /tmp/fastfetch_latest_$ARCH.deb || sudo apt-get install -f -y

    # Remove the downloaded .deb file
    rm /tmp/fastfetch_latest_$ARCH.deb

    echo "fastfetch has been successfully installed."
}

# Install Terminus font, ncdu, qemu-guest-agent, fastfetch, and yazi based on the OS
if [ "$OS" == "arch" ]; then
    echo "Installing for Arch Linux"
    sudo pacman -S --noconfirm --needed nano terminus-font ncdu qemu-guest-agent yazi cockpit wget timeshift
elif [ "$OS" == "debian" ]; then
    echo "Installing for Debian"
    sudo apt install -y nano fonts-terminus ncdu qemu-guest-agent cockpit wget
    install_fastfetch  # Call the fastfetch installation function
elif [ "$OS" == "fedora" ]; then
    echo "Installing for Fedora"
    sudo dnf install -y nano terminus-fonts-console ncdu qemu-guest-agent cockpit wget timeshift
    fi

# Function to check if Cockpit is installed
is_cockpit_installed() {
    if command -v cockpit >/dev/null 2>&1; then
        echo "Cockpit is already installed."
        return 0
    else
        return 1
    fi
}

# Function to install Cockpit and start it if not running
install_cockpit() {
    echo "Installing Cockpit..."

    case "$OS" in
        debian)
            sudo apt-get update -qq
            sudo apt-get install -y cockpit -qq
            ;;
        fedora)
            sudo dnf install -y cockpit -q
            ;;
        arch)
            sudo pacman -Sy cockpit --noconfirm >/dev/null
            ;;
    esac

    # Start Cockpit service
    if ! systemctl is-active --quiet cockpit; then
        sudo systemctl enable --now cockpit.socket
        echo "Cockpit service has been started."
    else
        echo "Cockpit service is already running."
    fi

    # Open firewall port for Cockpit (port 9090)
    if command -v ufw >/dev/null 2>&1; then
        sudo ufw allow 9090/tcp
        sudo ufw reload
        echo "UFW configuration updated to allow Cockpit."
    fi

    echo "Cockpit installation complete. Access it via https://<your-server-ip>:9090"
}

# Check if Cockpit is already installed
if is_cockpit_installed; then
    echo "Cockpit is already installed. Skipping installation."
else
    install_cockpit
fi

echo "-------------------------------------------------------------------------"
echo "                    Setting Permanent Console Font"
echo "-------------------------------------------------------------------------"

# Set permanent console font with sudo privileges
if [ "$OS" == "arch" ] || [ "$OS" == "fedora" ]; then
    echo "Setting console font to ter-v18b in /etc/vconsole.conf"
    echo "FONT=ter-v18b" | sudo tee -a /etc/vconsole.conf > /dev/null
elif [ "$OS" == "debian" ]; then
    echo "Setting console font to ter-v18b in /etc/default/console-setup"
    if grep -q '^FONT=' /etc/default/console-setup; then
        sudo sed -i 's/^FONT=.*/FONT="ter-v18b"/' /etc/default/console-setup
    else
        echo "FONT=ter-v18b" | sudo tee -a /etc/default/console-setup > /dev/null
    fi
fi

echo "-------------------------------------------------------------------------"
echo "                        Applications Installed                           "
echo "-------------------------------------------------------------------------"

# Reboot only if GPU drivers were installed
if [ "$reboot_required" = true ]; then
    echo "Rebooting the system in 5 seconds due to GPU driver installation..."
    sleep 5
    sudo reboot
else
    echo "No GPU drivers were installed, skipping reboot."
fi
