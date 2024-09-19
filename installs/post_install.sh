#!/bin/bash

set +e
reboot_required=false

# OS Detection
if [ -f /etc/arch-release ]; then
    OS="arch"
elif [ -f /etc/debian_version ]; then
    OS=$(grep -q "Ubuntu" /etc/lsb-release && echo "ubuntu" || echo "debian")
elif [ -f /etc/fedora-release ]; then
    OS="fedora"
else
    echo "Unsupported OS, but continuing with best-effort installation..."
    OS="unknown"
fi

# Function to install and configure Nala
install_nala() {
    [ "$OS" == "debian" ] || [ "$OS" == "ubuntu" ] || return
    echo "Installing Nala..."
    if sudo DEBIAN_FRONTEND=noninteractive apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nala; then
        yes | sudo nala fetch --auto --fetches 3 || echo "Nala fetch failed, continuing..."
        echo "Configuring nala as an alternative to apt..."
        echo "alias apt='nala'" | sudo tee -a /etc/bash.bashrc > /dev/null
        sudo tee /usr/local/bin/apt << EOF > /dev/null
#!/bin/sh
echo "apt has been replaced by nala. Running nala instead."
nala "\$@"
EOF
        sudo chmod +x /usr/local/bin/apt
        echo "Nala has been installed and set as an alternative to apt."
    else
        echo "Nala installation failed. Continuing with apt..."
    fi
}

# Install Nala if on Debian/Ubuntu
install_nala

# Enable parallel downloads
if [[ -f /etc/pacman.conf ]]; then
    sudo sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf || echo "Failed to enable ParallelDownloads for Pacman. Continuing..."
elif [[ -f /etc/dnf/dnf.conf ]] && ! grep -q '^max_parallel_downloads' /etc/dnf/dnf.conf; then
    echo 'max_parallel_downloads=10' | sudo tee -a /etc/dnf/dnf.conf || echo "Failed to enable max_parallel_downloads for DNF. Continuing..."
fi

echo "-------------------------------------------------------------------------"
echo "                    Installing Graphics Drivers"
echo "-------------------------------------------------------------------------"

# Detect GPU Type
gpu_type=$(lspci | grep -E "VGA|3D" || echo "No GPU detected")

# Graphics Drivers installation
if echo "${gpu_type}" | grep -qE "NVIDIA|GeForce"; then
    echo "Detected NVIDIA GPU"
    case "$OS" in
        arch)
            if [[ $(uname -r) == *lts* ]]; then
                sudo pacman -S --noconfirm --needed nvidia-lts nvidia-settings
            else
                sudo pacman -S --noconfirm --needed nvidia nvidia-settings
            fi
            ;;
        debian)
            # Detect Debian version
            if grep -q "bookworm" /etc/os-release; then
                echo "deb http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware" | sudo tee -a /etc/apt/sources.list
            elif grep -q "bullseye" /etc/os-release; then
                echo "deb http://deb.debian.org/debian/ bullseye main contrib non-free" | sudo tee -a /etc/apt/sources.list
            else
                echo "Unsupported Debian version. Skipping NVIDIA driver installation."
                return
            fi
            
            sudo apt update
            sudo DEBIAN_FRONTEND=noninteractive apt install -y nvidia-driver firmware-misc-nonfree
            ;;
        ubuntu)
            # Detect if it's a server or desktop environment
            if systemctl is-active --quiet gdm.service || systemctl is-active --quiet lightdm.service; then
                # Desktop environment
                sudo ubuntu-drivers install nvidia:535
            else
                # Server environment
                sudo ubuntu-drivers install --gpgpu nvidia:535-server
            fi
            ;;
        fedora)
            sudo dnf install -y kernel-devel kernel-headers gcc make dkms acpid libglvnd-glx libglvnd-opengl libglvnd-devel pkgconfig
            sudo dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
            sudo dnf install -y https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
            sudo dnf makecache
            sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda
            ;;
    esac
    reboot_required=true
elif echo "${gpu_type}" | grep -qE "Radeon|AMD"; then
    echo "Detected AMD GPU"
    case "$OS" in
        arch)
            sudo pacman -S --noconfirm --needed xf86-video-amdgpu
            ;;
        debian)
            # Add contrib and non-free to sources.list
            sudo sed -i 's/main$/main contrib non-free/' /etc/apt/sources.list
            sudo apt update
            sudo apt install -y linux-headers-amd64 firmware-linux firmware-linux-nonfree libdrm-amdgpu1
            sudo apt install -y firmware-amdgpu
            ;;
        ubuntu)
            # Install AMD GPU drivers for Ubuntu
            sudo add-apt-repository ppa:kisak/kisak-mesa -y
            sudo apt update
            sudo apt install -y mesa-vulkan-drivers mesa-vdpau-drivers
            sudo apt install -y libdrm-amdgpu1 xserver-xorg-video-amdgpu
            echo 'Section "Device"
    Identifier "AMD"
    Driver "amdgpu"
    Option "DRI" "3"
EndSection' | sudo tee /etc/X11/xorg.conf.d/20-amdgpu.conf
            sudo update-initramfs -u
            ;;
        fedora)
            sudo dnf install -y mesa-dri-drivers mesa-vulkan-drivers
            sudo dnf install -y xorg-x11-drv-amdgpu
            echo 'Section "Device"
    Identifier "AMD"
    Driver "amdgpu"
    Option "DRI" "3"
EndSection' | sudo tee /etc/X11/xorg.conf.d/20-amdgpu.conf
            sudo dracut --force
            ;;
    esac
    reboot_required=true
elif echo "${gpu_type}" | grep -qE "Intel"; then
    echo "Detected Intel GPU"
    case "$OS" in
        arch) sudo pacman -S --noconfirm --needed libva-intel-driver libvdpau-va-gl vulkan-intel intel-media-driver mesa lib32-mesa ;;
        debian|ubuntu) sudo DEBIAN_FRONTEND=noninteractive nala install -y intel-media-va-driver i965-va-driver vainfo mesa-vulkan-drivers ;;
        fedora) sudo dnf install -y intel-media-driver mesa-va-drivers mesa-vdpau-drivers mesa-vulkan-drivers libva-intel-driver ;;
    esac
    reboot_required=true
else
    echo "No supported GPU found or GPU detection failed. Continuing without GPU driver installation..."
fi

echo "-------------------------------------------------------------------------"
echo "                     Installing Network Manager                          "
echo "-------------------------------------------------------------------------"

# Install and enable NetworkManager
case "$OS" in
    arch) sudo pacman -S --noconfirm --needed networkmanager ;;
    debian|ubuntu) sudo DEBIAN_FRONTEND=noninteractive nala install -y network-manager ;;
    fedora) sudo dnf install -y NetworkManager ;;
esac

sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager

echo "-------------------------------------------------------------------------"
echo "                       Installing Applications                           "
echo "-------------------------------------------------------------------------"

# Function to install a package
install_package() {
    case "$OS" in
        arch) sudo pacman -S --noconfirm --needed $1 ;;
        debian|ubuntu) sudo DEBIAN_FRONTEND=noninteractive nala install -y $1 ;;
        fedora) sudo dnf install -y $1 ;;
        *) echo "Unable to install $1 on this OS. Continuing..." ;;
    esac
}

# Install common packages
common_packages="nano git wget ncdu qemu-guest-agent timeshift"
for package in $common_packages; do
    install_package $package
done

# OS-specific packages
case "$OS" in
    arch)
        install_package terminus-font
        install_package yazi
        install_package openssh
        ;;
    debian|ubuntu)
        install_package console-setup
        install_package xfonts-terminus
        install_package openssh-server
        ;;
    fedora)
        install_package terminus-fonts-console
        install_package openssh-server
        ;;
esac

# Enable and start SSH service and QEMU guest agent
sudo systemctl enable sshd
sudo systemctl start sshd
echo "SSH service has been enabled and started."

if systemctl list-unit-files | grep -q qemu-guest-agent; then
    sudo systemctl enable qemu-guest-agent
    sudo systemctl start qemu-guest-agent
    echo "QEMU guest agent has been enabled and started."
else
    echo "QEMU guest agent service not found. Skipping activation."
fi

echo "-------------------------------------------------------------------------"
echo "                    Setting Permanent Console Font"
echo "-------------------------------------------------------------------------"

# Set permanent console font
if [ "$OS" == "arch" ] || [ "$OS" == "fedora" ]; then
    echo "Setting console font to ter-v18b in /etc/vconsole.conf"
    grep -q '^FONT=' /etc/vconsole.conf && sudo sed -i 's/^FONT=.*/FONT=ter-v18b/' /etc/vconsole.conf || echo "FONT=ter-v18b" | sudo tee -a /etc/vconsole.conf > /dev/null
    sudo setfont ter-v18b
elif [ "$OS" == "debian" ] || [ "$OS" == "ubuntu" ]; then
    echo "Setting console font to Terminus in /etc/default/console-setup"
    sudo sed -i 's/^FONTFACE=.*/FONTFACE="Terminus"/' /etc/default/console-setup
    sudo sed -i 's/^FONTSIZE=.*/FONTSIZE="18x10"/' /etc/default/console-setup
    sudo update-initramfs -u
    sudo setfont /usr/share/consolefonts/Uni2-TerminusBold18x10.psf.gz
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