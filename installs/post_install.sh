#!/bin/bash

# Allow the script to continue on errors
set +e

reboot_required=false

# OS Detection
if [ -f /etc/arch-release ]; then
    OS="arch"
elif [ -f /etc/debian_version ]; then
    if [ -f /etc/lsb-release ] && grep -q "Ubuntu" /etc/lsb-release; then
        OS="ubuntu"
    else
        OS="debian"
    fi
elif [ -f /etc/fedora-release ]; then
    OS="fedora"
else
    echo "Unsupported OS, but continuing with best-effort installation..."
    OS="unknown"
fi

# Function to install and configure Nala
install_nala() {
    if [ "$OS" == "debian" ] || [ "$OS" == "ubuntu" ]; then
        echo "Installing Nala..."
        if sudo DEBIAN_FRONTEND=noninteractive apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nala; then
            # Configure nala
            sudo nala fetch --auto --fetches 3 < /dev/null || echo "Nala fetch failed, continuing..."

            # Make nala the default package manager
            echo "Configuring nala as the default package manager..."
            
            # Create aliases for apt commands
            echo "alias apt='nala'" | sudo tee -a /etc/bash.bashrc > /dev/null
            echo "alias apt-get='nala'" | sudo tee -a /etc/bash.bashrc > /dev/null
            echo "alias aptitude='nala'" | sudo tee -a /etc/bash.bashrc > /dev/null

            # Create scripts to intercept apt commands
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

            echo "Nala has been installed and set as the default package manager."
        else
            echo "Nala installation failed. Continuing with apt..."
        fi
    fi
}

# Install Nala if on Debian/Ubuntu
install_nala

# Function to enable parallel downloads based on OS
enable_parallel_downloads() {
    if [[ -f /etc/pacman.conf ]]; then
        echo "Enabling ParallelDownloads for Pacman..."
        sudo sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf || echo "Failed to enable ParallelDownloads for Pacman. Continuing..."
    elif [[ -f /etc/dnf/dnf.conf ]]; then
        echo "Enabling max_parallel_downloads for DNF..."
        if ! grep -q '^max_parallel_downloads' /etc/dnf/dnf.conf; then
            echo 'max_parallel_downloads=10' | sudo tee -a /etc/dnf/dnf.conf || echo "Failed to enable max_parallel_downloads for DNF. Continuing..."
        fi
    fi
}

# Enable parallel downloads for the detected OS
enable_parallel_downloads

echo "-------------------------------------------------------------------------"
echo "                    Installing Graphics Drivers"
echo "-------------------------------------------------------------------------"

# Detect GPU Type
gpu_type=$(lspci | grep -E "VGA|3D" || echo "No GPU detected")

# Graphics Drivers installation based on OS and GPU type
if echo "${gpu_type}" | grep -E "NVIDIA|GeForce"; then
    echo "Detected NVIDIA GPU"
    if [ "$OS" == "arch" ]; then
        sudo pacman -S --noconfirm --needed nvidia nvidia-settings || echo "NVIDIA driver installation failed. Continuing..."
    elif [ "$OS" == "debian" ] || [ "$OS" == "ubuntu" ]; then
        if [ "$OS" == "ubuntu" ]; then
            sudo DEBIAN_FRONTEND=noninteractive ubuntu-drivers autoinstall || echo "NVIDIA driver installation failed. Continuing..."
        else
            sudo DEBIAN_FRONTEND=noninteractive nala install -y nvidia-driver firmware-misc-nonfree || echo "NVIDIA driver installation failed. Continuing..."
        fi
    elif [ "$OS" == "fedora" ]; then
        sudo dnf install -y akmod-nvidia || echo "NVIDIA driver installation failed. Continuing..."
    fi
    reboot_required=true
elif echo "${gpu_type}" | grep 'VGA' | grep -E "Radeon|AMD"; then
    echo "Detected AMD GPU"
    if [ "$OS" == "arch" ]; then
        sudo pacman -S --noconfirm --needed xf86-video-amdgpu || echo "AMD driver installation failed. Continuing..."
    elif [ "$OS" == "debian" ] || [ "$OS" == "ubuntu" ]; then
        sudo DEBIAN_FRONTEND=noninteractive nala install -y firmware-amd-graphics || echo "AMD driver installation failed. Continuing..."
    elif [ "$OS" == "fedora" ]; then
        sudo dnf install -y xorg-x11-drv-amdgpu || echo "AMD driver installation failed. Continuing..."
    fi
    reboot_required=true
elif echo "${gpu_type}" | grep -E "Intel"; then
    echo "Detected Intel GPU"
    if [ "$OS" == "arch" ]; then
        sudo pacman -S --noconfirm --needed libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-utils lib32-mesa || echo "Intel driver installation failed. Continuing..."
    elif [ "$OS" == "debian" ] || [ "$OS" == "ubuntu" ]; then
        sudo DEBIAN_FRONTEND=noninteractive nala install -y intel-media-va-driver mesa-va-drivers mesa-vulkan-drivers || echo "Intel driver installation failed. Continuing..."
    elif [ "$OS" == "fedora" ]; then
        sudo dnf install -y intel-media-driver mesa-vulkan-drivers || echo "Intel driver installation failed. Continuing..."
    fi
    reboot_required=true
else
    echo "No supported GPU found or GPU detection failed. Continuing without GPU driver installation..."
fi

echo "-------------------------------------------------------------------------"
echo "                     Installing Network Manager                          "
echo "-------------------------------------------------------------------------"

# Install and enable NetworkManager
if [ "$OS" == "arch" ]; then
    sudo pacman -S --noconfirm --needed networkmanager || echo "NetworkManager installation failed. Continuing..."
elif [ "$OS" == "debian" ] || [ "$OS" == "ubuntu" ]; then
    sudo DEBIAN_FRONTEND=noninteractive nala install -y network-manager || echo "NetworkManager installation failed. Continuing..."
elif [ "$OS" == "fedora" ]; then
    sudo dnf install -y NetworkManager || echo "NetworkManager installation failed. Continuing..."
fi

sudo systemctl enable NetworkManager || echo "Failed to enable NetworkManager. Continuing..."
sudo systemctl start NetworkManager || echo "Failed to start NetworkManager. Continuing..."

echo "-------------------------------------------------------------------------"
echo "                       Installing Applications                           "
echo "-------------------------------------------------------------------------"

# Function to install a package
install_package() {
    if [ "$OS" == "arch" ]; then
        sudo pacman -S --noconfirm --needed $1 || echo "Failed to install $1. Continuing..."
    elif [ "$OS" == "debian" ] || [ "$OS" == "ubuntu" ]; then
        sudo DEBIAN_FRONTEND=noninteractive nala install -y $1 || echo "Failed to install $1. Continuing..."
    elif [ "$OS" == "fedora" ]; then
        sudo dnf install -y $1 || echo "Failed to install $1. Continuing..."
    else
        echo "Unable to install $1 on this OS. Continuing..."
    fi
}

# Install common packages
common_packages="nano git wget ncdu qemu-guest-agent timeshift"
for package in $common_packages; do
    install_package $package
done

# OS-specific packages
if [ "$OS" == "arch" ]; then
    install_package terminus-font
    install_package yazi
elif [ "$OS" == "debian" ] || [ "$OS" == "ubuntu" ]; then
    install_package console-setup
    install_package xfonts-terminus
    # Install fastfetch
    install_fastfetch || echo "Failed to install fastfetch. Continuing..."
elif [ "$OS" == "fedora" ]; then
    install_package terminus-fonts-console
fi

echo "-------------------------------------------------------------------------"
echo "                    Setting Permanent Console Font"
echo "-------------------------------------------------------------------------"

# Set permanent console font
if [ "$OS" == "arch" ] || [ "$OS" == "fedora" ]; then
    echo "Setting console font to ter-v18b in /etc/vconsole.conf"
    if grep -q '^FONT=' /etc/vconsole.conf; then
        sudo sed -i 's/^FONT=.*/FONT=ter-v18b/' /etc/vconsole.conf || echo "Failed to set console font. Continuing..."
    else
        echo "FONT=ter-v18b" | sudo tee -a /etc/vconsole.conf > /dev/null || echo "Failed to set console font. Continuing..."
    fi
    sudo setfont ter-v18b || echo "Failed to apply console font. Continuing..."
elif [ "$OS" == "debian" ] || [ "$OS" == "ubuntu" ]; then
    echo "Setting console font to Terminus in /etc/default/console-setup"
    sudo sed -i 's/^FONTFACE=.*/FONTFACE="Terminus"/' /etc/default/console-setup || echo "Failed to set console font face. Continuing..."
    sudo sed -i 's/^FONTSIZE=.*/FONTSIZE="18x10"/' /etc/default/console-setup || echo "Failed to set console font size. Continuing..."
    sudo update-initramfs -u || echo "Failed to update initramfs. Continuing..."
    sudo setfont /usr/share/consolefonts/Uni2-TerminusBold18x10.psf.gz || echo "Failed to apply console font. Continuing..."
fi

echo "-------------------------------------------------------------------------"
echo "                        Installation Complete                            "
echo "-------------------------------------------------------------------------"

if [ "$reboot_required" = true ]; then
    echo "Rebooting the system in 10 seconds due to driver installations..."
    sleep 10
    sudo reboot
else
    echo "No reboot required. All changes have been applied."
fi