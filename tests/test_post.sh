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

# Function to install packages based on OS
install_gpu_packages() {
    case "$OS" in
        arch) sudo pacman -S --noconfirm --needed $1 ;;
        debian|ubuntu) sudo DEBIAN_FRONTEND=noninteractive apt install -y $1 ;;
        fedora) sudo dnf install -y $1 ;;
    esac
}

# Graphics Drivers installation
if echo "${gpu_type}" | grep -qE "NVIDIA|GeForce"; then
    echo "Detected NVIDIA GPU"
    case "$OS" in
        arch)
            [[ $(uname -r) == *lts* ]] && nvidia_pkg="nvidia-lts" || nvidia_pkg="nvidia"
            install_gpu_packages "$nvidia_pkg nvidia-settings"
            ;;
        debian)
            debian_version=$(grep -oP '(?<=VERSION_CODENAME=).+' /etc/os-release)
            case $debian_version in
                bookworm|bullseye) repo="deb http://deb.debian.org/debian/ $debian_version main contrib non-free non-free-firmware" ;;
                *) echo "Unsupported Debian version. Skipping NVIDIA driver installation."; return ;;
            esac
            echo "$repo" | sudo tee -a /etc/apt/sources.list
            sudo apt update
            install_gpu_packages "nvidia-driver firmware-misc-nonfree"
            ;;
        ubuntu)
            if [[ "$1" == "--gpgpu" ]]; then
                sudo apt-get install nvidia-driver-535-server nvidia-utils-535-server
            else
                sudo ubuntu-drivers autoinstall
            fi
            ;;
        fedora)
            install_gpu_packages "kernel-devel kernel-headers gcc make dkms acpid libglvnd-glx libglvnd-opengl libglvnd-devel pkgconfig"
            sudo dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
            sudo dnf install -y https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
            sudo dnf makecache
            install_gpu_packages "akmod-nvidia xorg-x11-drv-nvidia-cuda"
            ;;
    esac
    reboot_required=true
elif echo "${gpu_type}" | grep -qE "Radeon|AMD"; then
    echo "Detected AMD GPU"
    case "$OS" in
        arch) install_gpu_packages "mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon libva-mesa-driver libva-utils" ;;
        debian)
            sudo sed -i 's/main$/main contrib non-free non-free-firmware/' /etc/apt/sources.list
            sudo apt update
            install_gpu_packages "firmware-amd-graphics libgl1-mesa-dri libglx-mesa0 mesa-vulkan-drivers xserver-xorg-video-all"
            ;;
        ubuntu)
            sudo add-apt-repository ppa:kisak/kisak-mesa -y
            sudo apt update
            install_gpu_packages "mesa-vulkan-drivers mesa-vdpau-drivers libdrm-amdgpu1 xserver-xorg-video-amdgpu"
            echo 'Section "Device"\n    Identifier "AMD"\n    Driver "amdgpu"\n    Option "DRI" "3"\nEndSection' | sudo tee /etc/X11/xorg.conf.d/20-amdgpu.conf
            sudo update-initramfs -u
            ;;
        fedora)
            install_gpu_packages "mesa-dri-drivers mesa-vulkan-drivers xorg-x11-drv-amdgpu"
            echo 'Section "Device"\n    Identifier "AMD"\n    Driver "amdgpu"\n    Option "DRI" "3"\nEndSection' | sudo tee /etc/X11/xorg.conf.d/20-amdgpu.conf
            sudo dracut --force
            ;;
    esac
    reboot_required=true
elif echo "${gpu_type}" | grep -qE "Intel"; then
    echo "Detected Intel GPU"
    case "$OS" in
        arch) install_gpu_packages "libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-utils lib32-mesa" ;;
        debian|ubuntu) install_gpu_packages "intel-media-va-driver i965-va-driver vainfo mesa-vulkan-drivers" ;;
        fedora) install_gpu_packages "intel-media-driver mesa-va-drivers mesa-vdpau-drivers mesa-vulkan-drivers libva-intel-driver" ;;
    esac
    reboot_required=true
else
    echo "No supported GPU found or GPU detection failed. Continuing without GPU driver installation..."
fi

echo "-------------------------------------------------------------------------"
echo "                Installing Applications and Network Manager              "
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

# OS-specific packages including NetworkManager
case "$OS" in
    arch) install_package "networkmanager terminus-font yazi openssh" ;;
    debian|ubuntu) install_package "network-manager console-setup xfonts-terminus openssh-server" ;;
    fedora) install_package "NetworkManager terminus-fonts-console openssh-server" ;;
esac

# Enable and start services
for service in NetworkManager ssh sshd qemu-guest-agent; do
    sudo systemctl enable $service &>/dev/null && echo "$service enabled" || echo "Failed to enable $service"
    sudo systemctl start $service &>/dev/null && echo "$service started" || echo "Failed to start $service"
done

echo "-------------------------------------------------------------------------"
echo "                    Setting Permanent Console Font"
echo "-------------------------------------------------------------------------"

# Set permanent console font
if [ "$OS" == "arch" ] || [ "$OS" == "fedora" ]; then
    echo "FONT=ter-v18b" | sudo tee /etc/vconsole.conf > /dev/null
    sudo setfont ter-v18b
elif [ "$OS" == "debian" ] || [ "$OS" == "ubuntu" ]; then
    sudo sed -i 's/^FONTFACE=.*/FONTFACE="Terminus"/' /etc/default/console-setup
    sudo sed -i 's/^FONTSIZE=.*/FONTSIZE="18x10"/' /etc/default/console-setup
    sudo sed -i 's/^CODESET=.*/CODESET="Uni2"/' /etc/default/console-setup
    sudo DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -f noninteractive console-setup
    sudo update-initramfs -u
    sudo setupcon --force
fi
echo "Console font settings have been applied and should persist after reboot."

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