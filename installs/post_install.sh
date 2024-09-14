#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

reboot_required=false

# Function to detect the package manager
detect_package_manager() {
    if command -v apt-get &> /dev/null; then
        PACKAGE_MANAGER="apt-get"
        PACKAGE_INSTALL="install -y"
        SUDO_GROUP="sudo"
        OS="debian"  # This covers both Debian and Ubuntu
    elif command -v dnf &> /dev/null; then
        PACKAGE_MANAGER="dnf"
        PACKAGE_INSTALL="install -y"
        SUDO_GROUP="wheel"
        OS="fedora"
    elif command -v yum &> /dev/null; then
        PACKAGE_MANAGER="yum"
        PACKAGE_INSTALL="install -y"
        SUDO_GROUP="wheel"
        OS="centos"
    elif command -v zypper &> /dev/null; then
        PACKAGE_MANAGER="zypper"
        PACKAGE_INSTALL="install -y"
        SUDO_GROUP="wheel"
        OS="opensuse"
    elif command -v apk &> /dev/null; then
        PACKAGE_MANAGER="apk"
        PACKAGE_INSTALL="add"
        SUDO_GROUP="wheel"
        OS="alpine"
    elif command -v pacman &> /dev/null; then
        PACKAGE_MANAGER="pacman"
        PACKAGE_INSTALL="-Sy --noconfirm"
        SUDO_GROUP="wheel"
        OS="arch"
    elif command -v emerge &> /dev/null; then
        PACKAGE_MANAGER="emerge"
        PACKAGE_INSTALL="--ask n"
        SUDO_GROUP="wheel"
        OS="gentoo"
    else
        echo "Unsupported package manager. Exiting."
        exit 1
    fi
}

# Detect package manager
detect_package_manager

echo "Detected package manager: $PACKAGE_MANAGER"
echo "Detected OS: $OS"

# Install and configure Nala for Debian and Ubuntu
install_nala() {
    if [ "$OS" == "debian" ]; then
        echo "Installing Nala on Debian/Ubuntu system..."
        sudo $PACKAGE_MANAGER update
        sudo $PACKAGE_MANAGER $PACKAGE_INSTALL nala -y
        
        # Replace apt with nala
        PACKAGE_MANAGER="nala"
        PACKAGE_INSTALL="install"
        
        # Configure nala
        sudo nala fetch --auto --fetches 3
        echo "Nala installed and configured."
    fi
}

# Install Nala if on Debian/Ubuntu
install_nala

# Detect GPU Type
gpu_type=$(lspci | grep -E "VGA|3D")

# Function to enable parallel downloads based on OS
enable_parallel_downloads() {
    case $PACKAGE_MANAGER in
        "pacman")
            echo "Enabling ParallelDownloads for Pacman..."
            sudo sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
            ;;
        "apt-get"|"nala")
            echo "Parallel downloads already enabled with Nala"
            ;;
        "dnf"|"yum")
            echo "Enabling max_parallel_downloads for DNF/YUM..."
            if grep -q '^#max_parallel_downloads' /etc/dnf/dnf.conf; then
                sudo sed -i 's/^#max_parallel_downloads/max_parallel_downloads/' /etc/dnf/dnf.conf
            elif ! grep -q '^max_parallel_downloads' /etc/dnf/dnf.conf; then
                echo 'max_parallel_downloads=10' | sudo tee -a /etc/dnf/dnf.conf
            fi
            ;;
        *)
            echo "Parallel download configuration not available for $PACKAGE_MANAGER"
            ;;
    esac
}

# Enable parallel downloads
enable_parallel_downloads

# Graphics Drivers installation based on OS and GPU type
if echo "${gpu_type}" | grep -E "NVIDIA|GeForce"; then
    echo "Detected NVIDIA GPU"
    case $OS in
        "arch")
            sudo $PACKAGE_MANAGER $PACKAGE_INSTALL nvidia nvidia-settings
            ;;
        "debian"|"ubuntu")
            if [ "$OS" == "ubuntu" ]; then
                sudo ubuntu-drivers autoinstall
            else
                sudo $PACKAGE_MANAGER $PACKAGE_INSTALL nvidia-driver firmware-misc-nonfree
            fi
            ;;
        "fedora"|"centos")
            sudo $PACKAGE_MANAGER $PACKAGE_INSTALL akmod-nvidia
            ;;
        *)
            echo "NVIDIA driver installation not configured for $OS"
            ;;
    esac
    reboot_required=true
elif echo "${gpu_type}" | grep 'VGA' | grep -E "Radeon|AMD"; then
    echo "Detected AMD GPU"
    case $OS in
        "arch")
            sudo $PACKAGE_MANAGER $PACKAGE_INSTALL xf86-video-amdgpu
            ;;
        "debian"|"ubuntu")
            sudo $PACKAGE_MANAGER $PACKAGE_INSTALL firmware-amd-graphics
            ;;
        "fedora"|"centos")
            sudo $PACKAGE_MANAGER $PACKAGE_INSTALL xorg-x11-drv-amdgpu
            ;;
        *)
            echo "AMD driver installation not configured for $OS"
            ;;
    esac
    reboot_required=true
elif echo "${gpu_type}" | grep -E "Intel"; then
    echo "Detected Intel GPU"
    case $OS in
        "arch")
            sudo $PACKAGE_MANAGER $PACKAGE_INSTALL libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-utils lib32-mesa
            ;;
        "debian"|"ubuntu")
            sudo $PACKAGE_MANAGER $PACKAGE_INSTALL intel-media-va-driver mesa-va-drivers mesa-vulkan-drivers
            ;;
        "fedora"|"centos")
            sudo $PACKAGE_MANAGER $PACKAGE_INSTALL intel-media-driver mesa-vulkan-drivers
            ;;
        *)
            echo "Intel driver installation not configured for $OS"
            ;;
    esac
    reboot_required=true
else
    echo "No supported GPU found"
fi

# Install and enable NetworkManager
sudo $PACKAGE_MANAGER $PACKAGE_INSTALL networkmanager
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager

# Install common applications
common_apps="nano git ncdu qemu-guest-agent wget"
case $OS in
    "arch")
        sudo $PACKAGE_MANAGER $PACKAGE_INSTALL $common_apps terminus-font yazi timeshift
        ;;
    "debian"|"ubuntu")
        sudo $PACKAGE_MANAGER $PACKAGE_INSTALL $common_apps console-setup xfonts-terminus timeshift
        ;;
    "fedora"|"centos")
        sudo $PACKAGE_MANAGER $PACKAGE_INSTALL $common_apps terminus-fonts-console timeshift
        ;;
    *)
        sudo $PACKAGE_MANAGER $PACKAGE_INSTALL $common_apps
        echo "Some applications may not be available for $OS"
        ;;
esac

# Set permanent console font
case $OS in
    "arch"|"fedora"|"centos")
        echo "Setting console font to ter-v18b in /etc/vconsole.conf"
        if grep -q '^FONT=' /etc/vconsole.conf; then
            sudo sed -i 's/^FONT=.*/FONT=ter-v18b/' /etc/vconsole.conf
        else
            echo "FONT=ter-v18b" | sudo tee -a /etc/vconsole.conf > /dev/null
        fi
        sudo setfont ter-v18b
        ;;
    "debian"|"ubuntu")
        echo "Setting console font to Terminus in /etc/default/console-setup"
        sudo sed -i 's/^FONTFACE=.*/FONTFACE="Terminus"/' /etc/default/console-setup
        sudo sed -i 's/^FONTSIZE=.*/FONTSIZE="18x10"/' /etc/default/console-setup
        sudo update-initramfs -u
        sudo setfont /usr/share/consolefonts/Uni2-TerminusBold18x10.psf.gz
        ;;
    *)
        echo "Console font setting not configured for $OS"
        ;;
esac

# Install Cockpit
if ! command -v cockpit &> /dev/null; then
    echo "Installing Cockpit..."
    sudo $PACKAGE_MANAGER $PACKAGE_INSTALL cockpit
    sudo systemctl enable --now cockpit.socket

    # Open firewall port for Cockpit (port 9090)
    if command -v ufw &> /dev/null; then
        sudo ufw allow 9090/tcp
        sudo ufw reload
    elif command -v firewall-cmd &> /dev/null; then
        sudo firewall-cmd --permanent --add-service=cockpit
        sudo firewall-cmd --reload
    else
        echo "No firewall manager found. Skipping firewall configuration."
    fi

    echo "Cockpit installation complete. Access it via https://<your-server-ip>:9090"
else
    echo "Cockpit is already installed. Skipping installation."
fi

if [ "$reboot_required" = true ]; then
    echo "Rebooting the system in 5 seconds due to GPU driver installation..."
    sleep 5
    sudo reboot
else
    echo "No GPU drivers were installed, skipping reboot."
fi