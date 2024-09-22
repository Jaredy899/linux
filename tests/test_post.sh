#!/bin/bash

set +e
reboot_required=false

# OS Detection
OS=$(case "" in
  $(grep -qs "Ubuntu" /etc/lsb-release && echo ubuntu)) ubuntu ;;
  $(test -f /etc/debian_version && echo debian)) debian ;;
  $(test -f /etc/arch-release && echo arch)) arch ;;
  $(test -f /etc/fedora-release && echo fedora)) fedora ;;
  *) echo "unknown" ;;
esac)

# Function to install packages based on OS
install_package() {
    case "$OS" in
        arch) sudo pacman -S --noconfirm --needed "$@" ;;
        debian|ubuntu) sudo DEBIAN_FRONTEND=noninteractive nala install -y "$@" ;;
        fedora) sudo dnf install -y "$@" ;;
        *) echo "Unable to install $* on this OS. Continuing..." ;;
    esac
}

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
[ "$OS" = "debian" ] || [ "$OS" = "ubuntu" ] && install_nala

# Enable parallel downloads
case "$OS" in
    arch) sudo sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf ;;
    fedora) echo 'max_parallel_downloads=10' | sudo tee -a /etc/dnf/dnf.conf ;;
esac

echo "Installing Graphics Drivers"

# Detect GPU Type and install drivers
gpu_type=$(lspci | grep -E "VGA|3D" || echo "No GPU detected")

if echo "$gpu_type" | grep -qE "NVIDIA|GeForce"; then
    echo "Detected NVIDIA GPU"
    case "$OS" in
        arch) install_package nvidia${uname -r | grep -q lts && echo "-lts"} nvidia-settings ;;
        debian|ubuntu)
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
            install_package kernel-devel kernel-headers gcc make dkms acpid libglvnd-glx libglvnd-opengl libglvnd-devel pkgconfig
            sudo dnf install -y https://download1.rpmfusion.org/{free/fedora/rpmfusion-free,nonfree/fedora/rpmfusion-nonfree}-release-$(rpm -E %fedora).noarch.rpm
            install_package akmod-nvidia xorg-x11-drv-nvidia-cuda
            ;;
    esac
    reboot_required=true
elif echo "$gpu_type" | grep -qE "Radeon|AMD"; then
    echo "Detected AMD GPU"
    case "$OS" in
        arch) install_package xf86-video-amdgpu ;;
        debian|ubuntu)
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
            install_package mesa-dri-drivers mesa-vulkan-drivers xorg-x11-drv-amdgpu
            echo 'Section "Device"
    Identifier "AMD"
    Driver "amdgpu"
    Option "DRI" "3"
EndSection' | sudo tee /etc/X11/xorg.conf.d/20-amdgpu.conf
            sudo dracut --force
            ;;
    esac
    reboot_required=true
elif echo "$gpu_type" | grep -qE "Intel"; then
    echo "Detected Intel GPU"
    case "$OS" in
        arch) install_package libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils lib32-mesa ;;
        debian|ubuntu) install_package intel-media-va-driver i965-va-driver vainfo mesa-vulkan-drivers ;;
        fedora) install_package intel-media-driver mesa-va-drivers mesa-vdpau-drivers mesa-vulkan-drivers libva-intel-driver ;;
    esac
    reboot_required=true
else
    echo "No supported GPU found or GPU detection failed. Continuing without GPU driver installation..."
fi

echo "Installing Applications"
install_package nano git wget ncdu qemu-guest-agent timeshift openssh-server

echo "Installing OS-specific packages"
case "$OS" in
    arch) install_package terminus-font yazi networkmanager ;;
    debian|ubuntu) install_package console-setup xfonts-terminus network-manager ;;
    fedora) install_package terminus-fonts-console NetworkManager ;;
esac

# Enable and start NetworkManager
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager

# Enable and start SSH service and QEMU guest agent
sudo systemctl enable --now sshd
systemctl list-unit-files | grep -q qemu-guest-agent && sudo systemctl enable --now qemu-guest-agent

echo "Setting Permanent Console Font"
if [ "$OS" = "arch" ] || [ "$OS" = "fedora" ]; then
    echo "FONT=ter-v18b" | sudo tee -a /etc/vconsole.conf
    sudo setfont ter-v18b
elif [ "$OS" = "debian" ] || [ "$OS" = "ubuntu" ]; then
    sudo sed -i 's/^FONTFACE=.*/FONTFACE="Terminus"/' /etc/default/console-setup
    sudo sed -i 's/^FONTSIZE=.*/FONTSIZE="18x10"/' /etc/default/console-setup
    sudo sed -i 's/^CODESET=.*/CODESET="Uni2"/' /etc/default/console-setup
    sudo DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -f noninteractive console-setup
    sudo update-initramfs -u
    sudo setupcon --force
fi

echo "Installation Complete"

if [ "$reboot_required" = true ]; then
    echo "Rebooting the system in 10 seconds due to driver installations..."
    sleep 10
    sudo reboot
else
    echo "No reboot required. All changes have been applied."
fi