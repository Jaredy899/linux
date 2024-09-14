#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

reboot_required=false

# Function to detect the package manager
detect_package_manager() {
    if command -v apt-get &> /dev/null; then
        PACKAGE_MANAGER="apt-get"
        PACKAGE_INSTALL="install -y"
        PACKAGE_CHECK="dpkg -s"
        SUDO_GROUP="sudo"
        OS="debian"  # This covers both Debian and Ubuntu
    elif command -v dnf &> /dev/null; then
        PACKAGE_MANAGER="dnf"
        PACKAGE_INSTALL="install -y"
        PACKAGE_CHECK="rpm -q"
        SUDO_GROUP="wheel"
        OS="fedora"
    elif command -v yum &> /dev/null; then
        PACKAGE_MANAGER="yum"
        PACKAGE_INSTALL="install -y"
        PACKAGE_CHECK="rpm -q"
        SUDO_GROUP="wheel"
        OS="centos"
    elif command -v zypper &> /dev/null; then
        PACKAGE_MANAGER="zypper"
        PACKAGE_INSTALL="install -y"
        PACKAGE_CHECK="rpm -q"
        SUDO_GROUP="wheel"
        OS="opensuse"
    elif command -v apk &> /dev/null; then
        PACKAGE_MANAGER="apk"
        PACKAGE_INSTALL="add"
        PACKAGE_CHECK="apk info -e"
        SUDO_GROUP="wheel"
        OS="alpine"
    elif command -v pacman &> /dev/null; then
        PACKAGE_MANAGER="pacman"
        PACKAGE_INSTALL="-Sy --noconfirm"
        PACKAGE_CHECK="pacman -Qi"
        SUDO_GROUP="wheel"
        OS="arch"
    elif command -v emerge &> /dev/null; then
        PACKAGE_MANAGER="emerge"
        PACKAGE_INSTALL="--ask n"
        PACKAGE_CHECK="equery list -i"
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

# Function to check if a package is installed
is_package_installed() {
    $PACKAGE_CHECK "$1" &> /dev/null
}

# Function to install a package if it's not already installed
install_package() {
    if ! is_package_installed "$1"; then
        echo "Installing $1..."
        sudo $PACKAGE_MANAGER $PACKAGE_INSTALL "$1"
    else
        echo "$1 is already installed. Skipping."
    fi
}

# Install and configure Nala for Debian and Ubuntu
install_nala() {
    if [ "$OS" == "debian" ]; then
        if ! is_package_installed nala; then
            echo "Installing Nala on Debian/Ubuntu system..."
            sudo $PACKAGE_MANAGER update
            sudo $PACKAGE_MANAGER $PACKAGE_INSTALL nala -y
            
            # Configure nala
            sudo nala fetch --auto --fetches 3
            echo "Nala installed and configured."
        else
            echo "Nala is already installed. Skipping."
        fi
        
        # Replace apt with nala
        PACKAGE_MANAGER="nala"
        PACKAGE_INSTALL="install"
        PACKAGE_CHECK="dpkg -s"

        # Make nala the default package manager
        echo "Configuring nala as the default package manager..."
        
        # Create aliases for apt commands
        echo "alias apt='nala'" | sudo tee -a /etc/bash.bashrc > /dev/null
        echo "alias apt-get='nala'" | sudo tee -a /etc/bash.bashrc > /dev/null
        echo "alias aptitude='nala'" | sudo tee -a /etc/bash.bashrc > /dev/null

        # Create a script to intercept apt commands
        sudo tee /usr/local/bin/apt << EOF > /dev/null
#!/bin/sh
echo "apt has been replaced by nala. Running nala instead."
nala "\$@"
EOF
        sudo chmod +x /usr/local/bin/apt

        sudo tee /usr/local/bin/apt-get << EOF > /dev/null
#!/bin/sh
echo "apt-get has been replaced by nala. Running nala instead."
nala "\$@"
EOF
        sudo chmod +x /usr/local/bin/apt-get

        echo "Nala has been set as the default package manager."
    fi
}

# Install Nala if on Debian/Ubuntu
install_nala

# Install package containing lspci
install_lspci() {
    case $OS in
        "debian"|"ubuntu"|"fedora"|"centos"|"arch"|"opensuse"|"alpine")
            install_package pciutils
            ;;
        "gentoo")
            install_package sys-apps/pciutils
            ;;
        *)
            echo "Unable to install lspci. Please install it manually."
            exit 1
            ;;
    esac
}

# Install lspci
install_lspci

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
            install_package nvidia
            install_package nvidia-settings
            ;;
        "debian"|"ubuntu")
            if [ "$OS" == "ubuntu" ]; then
                sudo ubuntu-drivers autoinstall
            else
                install_package nvidia-driver
                install_package firmware-misc-nonfree
            fi
            ;;
        "fedora"|"centos")
            install_package akmod-nvidia
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
            install_package xf86-video-amdgpu
            ;;
        "debian"|"ubuntu")
            install_package firmware-amd-graphics
            ;;
        "fedora"|"centos")
            install_package xorg-x11-drv-amdgpu
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
            install_package libva-intel-driver
            install_package libvdpau-va-gl
            install_package lib32-vulkan-intel
            install_package vulkan-intel
            install_package libva-utils
            install_package lib32-mesa
            ;;
        "debian"|"ubuntu")
            install_package intel-media-va-driver
            install_package mesa-va-drivers
            install_package mesa-vulkan-drivers
            ;;
        "fedora"|"centos")
            install_package intel-media-driver
            install_package mesa-vulkan-drivers
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
install_package networkmanager
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager

# Install common applications
common_apps="nano git ncdu qemu-guest-agent wget"
for app in $common_apps; do
    install_package $app
done

case $OS in
    "arch")
        install_package terminus-font
        install_package yazi
        install_package timeshift
        ;;
    "debian"|"ubuntu")
        install_package console-setup
        install_package xfonts-terminus
        install_package timeshift
        ;;
    "fedora"|"centos")
        install_package terminus-fonts-console
        install_package timeshift
        ;;
    *)
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
if ! is_package_installed cockpit; then
    echo "Installing Cockpit..."
    install_package cockpit
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