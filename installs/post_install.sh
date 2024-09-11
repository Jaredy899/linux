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

# Function to enable parallel downloads based on OS
enable_parallel_downloads() {
    if [[ -f /etc/pacman.conf ]]; then
        # Enable ParallelDownloads in Pacman (Arch Linux)
        echo "Enabling ParallelDownloads for Pacman..."
        sudo sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
        echo "ParallelDownloads enabled for Pacman."

    elif [[ -f /etc/apt/apt.conf.d/90parallel ]]; then
        # Enable parallel downloading for APT (Debian-based)
        echo "Enabling parallel downloads for APT..."
        sudo tee /etc/apt/apt.conf.d/90parallel > /dev/null <<EOL
APT::Acquire::Retries "3";
APT::Acquire::Queue-Mode "access";
APT::Acquire::http { Pipeline-Depth "200"; };
EOL
        echo "Parallel downloads enabled for APT."

    elif [[ -f /etc/dnf/dnf.conf ]]; then
        # Enable max_parallel_downloads for DNF (Fedora)
        echo "Enabling max_parallel_downloads for DNF..."
        if grep -q '^#max_parallel_downloads' /etc/dnf/dnf.conf; then
            sudo sed -i 's/^#max_parallel_downloads/max_parallel_downloads/' /etc/dnf/dnf.conf
        elif ! grep -q '^max_parallel_downloads' /etc/dnf/dnf.conf; then
            echo 'max_parallel_downloads=10' | sudo tee -a /etc/dnf/dnf.conf
        fi
        echo "max_parallel_downloads enabled for DNF."

    else
        echo "Package manager not supported or configuration file not found."
    fi
}

# Enable parallel downloads for the detected OS
enable_parallel_downloads

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
    sudo systemctl enable NetworkManager
    sudo systemctl start NetworkManager
elif [ "$OS" == "debian" ]; then
    sudo apt install -y network-manager
    sudo systemctl enable NetworkManager
    sudo systemctl start NetworkManager
elif [ "$OS" == "fedora" ]; then
    sudo dnf install -y NetworkManager
    sudo systemctl enable NetworkManager
    sudo systemctl start NetworkManager
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
    sudo pacman -S --noconfirm --needed nano git terminus-font ncdu qemu-guest-agent yazi cockpit wget timeshift
elif [ "$OS" == "debian" ]; then
    echo "Installing for Debian"
    sudo apt install -y nano console-setup xfonts-terminus ncdu qemu-guest-agent cockpit wget git 
    install_fastfetch  # Call the fastfetch installation function
elif [ "$OS" == "fedora" ]; then
    echo "Installing for Fedora"
    sudo dnf install -y nano terminus-fonts-console ncdu qemu-guest-agent cockpit wget timeshift git
    fi

echo "-------------------------------------------------------------------------"
echo "                    Setting Permanent Console Font"
echo "-------------------------------------------------------------------------"

# Set permanent console font with sudo privileges
if [ "$OS" == "arch" ] || [ "$OS" == "fedora" ]; then
    echo "Setting console font to ter-v18b in /etc/vconsole.conf"
    
    # Replace FONT line if it exists, otherwise add it
    if grep -q '^FONT=' /etc/vconsole.conf; then
        sudo sed -i 's/^FONT=.*/FONT=ter-v18b/' /etc/vconsole.conf
    else
        echo "FONT=ter-v18b" | sudo tee -a /etc/vconsole.conf > /dev/null
    fi

    # Apply the font change immediately
    echo "Applying the console font immediately"
    sudo setfont ter-v18b

elif [ "$OS" == "debian" ] || [ "$OS" == "ubuntu" ]; then
    echo "Setting console font to Terminus in /etc/default/console-setup"
    sudo sed -i 's/^FONTFACE=.*/FONTFACE="Terminus"/' /etc/default/console-setup
    sudo sed -i 's/^FONTSIZE=.*/FONTSIZE="18x10"/' /etc/default/console-setup
    
    echo "Updating initramfs to apply changes"
    sudo update-initramfs -u

    echo "Setting the font immediately"
    sudo setfont /usr/share/consolefonts/Uni2-TerminusBold18x10.psf.gz
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

# Function to check if running in chroot
is_chroot() {
    if [ "$(stat -c %d:%i /proc/1/root)" != "$(stat -c %d:%i /)" ]; then
        return 0  # In chroot
    else
        return 1  # Not in chroot
    fi
}

# Function to install Cockpit and enable it
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

    # Check if running in chroot
    if is_chroot; then
        echo "Running in chroot: enabling Cockpit for first boot"
        # Only enable cockpit for next boot, don't start it in chroot
        sudo systemctl enable cockpit.socket

        # Prepare first-boot service to ensure Cockpit starts after reboot
        cat << 'EOF' | sudo tee /mnt/etc/systemd/system/first-boot.service > /dev/null
[Unit]
Description=First boot service to start Cockpit
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/systemctl start cockpit.socket
ExecStartPost=/usr/bin/systemctl disable first-boot.service
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

        # Enable first-boot service
        sudo systemctl enable first-boot.service
    else
        echo "Not in chroot: enabling and starting Cockpit now"
        # If not in chroot, enable and start cockpit immediately
        sudo systemctl enable --now cockpit.socket
    fi

    # Open firewall port for Cockpit (port 9090)
    if command -v ufw >/dev/null 2>&1; then
        sudo ufw allow 9090/tcp
        sudo ufw reload
        echo "UFW configuration updated to allow Cockpit."
    elif command -v firewall-cmd >/dev/null 2>&1; then
        sudo firewall-cmd --permanent --add-service=cockpit
        sudo firewall-cmd --reload
        echo "FirewallD configuration updated to allow Cockpit."
    else
        echo "No firewall manager found. Skipping firewall configuration."
    fi

    echo "Cockpit installation complete. Access it via https://<your-server-ip>:9090"
}

# Function to prompt user for installation
prompt_cockpit_install() {
    read -p "Do you want to install Cockpit? (y/n): " answer
    case "$answer" in
        [Yy]* ) install_cockpit ;;
        [Nn]* ) echo "Skipping Cockpit installation." ;;
        * ) echo "Please answer yes or no." ;;
    esac
}

# Check if Cockpit is already installed
if is_cockpit_installed; then
    echo "Cockpit is already installed. Skipping installation."
else
    prompt_cockpit_install
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
