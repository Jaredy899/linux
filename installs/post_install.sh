#!/bin/bash

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
    elif [ "$OS" == "debian" ]; then
        echo "Installing NVIDIA drivers"
        sudo apt install -y nvidia-driver
    elif [ "$OS" == "fedora" ]; then
        echo "Installing NVIDIA drivers"
        sudo dnf install -y akmod-nvidia
    fi
elif echo "${gpu_type}" | grep 'VGA' | grep -E "Radeon|AMD"; then
    echo "Detected AMD GPU"
    if [ "$OS" == "arch" ]; then
        echo "Installing AMD drivers: xf86-video-amdgpu"
        sudo pacman -S --noconfirm --needed xf86-video-amdgpu
    elif [ "$OS" == "debian" ]; then
        echo "Installing AMD drivers"
        sudo apt install -y firmware-amd-graphics
    elif [ "$OS" == "fedora" ]; then
        echo "Installing AMD drivers"
        sudo dnf install -y xorg-x11-drv-amdgpu
    fi
elif echo "${gpu_type}" | grep -E "Intel"; then
    echo "Detected Intel GPU"
    if [ "$OS" == "arch" ]; then
        echo "Installing Intel drivers"
        sudo pacman -S --noconfirm --needed libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-utils lib32-mesa
    elif [ "$OS" == "debian" ]; then
        echo "Installing Intel drivers"
        sudo apt install -y intel-media-va-driver mesa-va-drivers mesa-vulkan-drivers
    elif [ "$OS" == "fedora" ]; then
        echo "Installing Intel drivers"
        sudo dnf install -y intel-media-driver mesa-vulkan-drivers
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

# Install Terminus font, ncdu, qemu-guest-agent, and yazi based on the OS
if [ "$OS" == "arch" ]; then
    echo "Installing for Arch Linux"
    sudo pacman -S --noconfirm --needed nano terminus-font ncdu qemu-guest-agent yazi cockpit
elif [ "$OS" == "debian" ]; then
    echo "Installing for Debian"
    sudo apt install -y nano console-terminus ncdu qemu-guest-agent cockpit
    # Install yazi from GitHub
    wget https://github.com/sxyazi/yazi/releases/download/latest/yazi-linux -O /usr/local/bin/yazi
    sudo chmod +x /usr/local/bin/yazi
elif [ "$OS" == "fedora" ]; then
    echo "Installing for Fedora"
    sudo dnf install -y nano terminus-fonts-console ncdu qemu-guest-agent cockpit
    # Install yazi from GitHub
    wget https://github.com/sxyazi/yazi/releases/download/latest/yazi-linux -O /usr/local/bin/yazi
    sudo chmod +x /usr/local/bin/yazi
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

# Function to detect architecture for Fastfetch
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

# Function to install Fastfetch
install_fastfetch() {
    echo "Installing Fastfetch..."

    if [ "$OS" == "arch" ]; then
        sudo pacman -S --noconfirm fastfetch
    elif [ "$OS" == "fedora" ]; then
        sudo dnf install -y fastfetch
    elif [ "$OS" == "debian" ]; then
        GITHUB_API_URL="https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest"
        ARCH_DEB=$(detect_arch)
        if [ "$ARCH_DEB" = "unsupported" ]; then
            echo "Unsupported architecture for Fastfetch. Exiting."
            exit 1
        fi
        FASTFETCH_URL=$(curl -s $GITHUB_API_URL | grep "browser_download_url.*$ARCH_DEB" | cut -d '"' -f 4)
        if [ -z "$FASTFETCH_URL" ]; then
            echo "Failed to retrieve Fastfetch URL. Exiting."
            exit 1
        fi
        curl -s -L --retry 3 -o /tmp/fastfetch_latest_$ARCH.deb "$FASTFETCH_URL"
        sudo dpkg -i /tmp/fastfetch_latest_$ARCH.deb || sudo apt-get install -f -y
        rm /tmp/fastfetch_latest_$ARCH.deb
        echo "Fastfetch has been successfully installed."
    fi
}

# Install Fastfetch
install_fastfetch

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

# Reboot after the installation completes
echo "Rebooting the system in 5 seconds..."
sleep 5
reboot