#!/bin/sh -e

# Set SKIP_AUR_CHECK to ignore AUR helper check
SKIP_AUR_CHECK=true

# Source the common script directly from GitHub
eval "$(curl -s https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/common_script.sh)"
eval "$(curl -s https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/common_service_script.sh)"

# Run the environment check
checkEnv || exit 1

reboot_required=false

# Function to install a package
install_package() {
    for package_name in "$@"; do
        if ! command_exists "$package_name"; then
            printf "%b\n" "${YELLOW}Installing $package_name...${RC}"
            noninteractive "$package_name"
        else
            printf "%b\n" "${GREEN}$package_name is already installed.${RC}"
        fi
    done
}

# Detect timezone
detected_timezone="$(curl --fail https://ipapi.co/timezone)"
if [ -n "$detected_timezone" ]; then
    printf "%b\n" "${CYAN}Detected timezone: $detected_timezone${RC}"
    if [ -e /usr/bin/timedatectl ]; then
        "$ESCALATION_TOOL" timedatectl set-timezone "$detected_timezone" || printf "%b\n" "${YELLOW}Failed to set timezone. This may be due to running in a chroot environment.${RC}"
    else
        "$ESCALATION_TOOL" ln -sf /usr/share/zoneinfo/$detected_timezone /etc/localtime
    fi
    printf "%b\n" "${GREEN}Timezone set to $detected_timezone${RC}"
else
    printf "%b\n" "${YELLOW}Failed to detect timezone. Please set it manually if needed.${RC}"
fi

# Enable Alpine repositories
if [ "$DTYPE" = "alpine" ]; then
    printf "%b\n" "${CYAN}Enabling community repository...${RC}"
    # Extract version from main repository
    ALPINE_VERSION=$(grep "mirror.ette.biz/alpine/v[0-9].[0-9]*/main" /etc/apk/repositories | sed 's|.*/alpine/\(v[0-9][.][0-9][0-9]*\)/main|\1|')
    if grep -q "mirror.ette.biz/alpine/v[0-9].[0-9]*/community" /etc/apk/repositories; then
        # Repository exists, just uncomment it
        "$ESCALATION_TOOL" sed -i 's/^#//' /etc/apk/repositories
    else
        # Repository doesn't exist, add it using the exact version number
        echo "http://mirror.ette.biz/alpine/$ALPINE_VERSION/community" | "$ESCALATION_TOOL" tee -a /etc/apk/repositories > /dev/null
    fi
    "$ESCALATION_TOOL" apk update
    printf "%b\n" "${GREEN}Alpine repositories updated${RC}"
fi

# Function to install and configure Nala
install_nala() {
    printf "%b\n" "${CYAN}Checking if Nala should be installed...${RC}"
    if [ "$DTYPE" = "debian" ] || [ "$DTYPE" = "ubuntu" ]; then
        printf "%b\n" "${CYAN}Installing Nala...${RC}"
        if "$ESCALATION_TOOL" DEBIAN_FRONTEND=noninteractive apt-get update && noninteractive nala; then
            yes | "$ESCALATION_TOOL" nala fetch --auto --fetches 3 || printf "%b\n" "${YELLOW}Nala fetch failed, continuing...${RC}"
            printf "%b\n" "${CYAN}Configuring nala as an alternative to apt...${RC}"
            echo "alias apt='nala'" | "$ESCALATION_TOOL" tee -a /etc/bash.bashrc > /dev/null
            "$ESCALATION_TOOL" tee /usr/local/bin/apt << EOF > /dev/null
#!/bin/sh
echo "apt has been replaced by nala. Running nala instead."
nala "\$@"
EOF
            "$ESCALATION_TOOL" chmod +x /usr/local/bin/apt
            printf "%b\n" "${GREEN}Nala has been installed and set as an alternative to apt.${RC}"
        else
            printf "%b\n" "${YELLOW}Nala installation failed. Continuing with apt...${RC}"
        fi
    else
        printf "%b\n" "${YELLOW}Not a Debian/Ubuntu system. Skipping Nala installation.${RC}"
    fi
}

# Debug output to check the detected distribution type
printf "%b\n" "${CYAN}Current distribution type detected as: $DTYPE${RC}"

# Explicitly call the install_nala function
printf "%b\n" "${CYAN}Attempting to install Nala...${RC}"
install_nala

# Enable parallel downloads
if [ -f /etc/pacman.conf ]; then
    "$ESCALATION_TOOL" sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf || printf "%b\n" "${YELLOW}Failed to enable ParallelDownloads for Pacman. Continuing...${RC}"
elif [ -f /etc/dnf/dnf.conf ] && ! grep -q '^max_parallel_downloads' /etc/dnf/dnf.conf; then
    echo 'max_parallel_downloads=10' | "$ESCALATION_TOOL" tee -a /etc/dnf/dnf.conf || printf "%b\n" "${YELLOW}Failed to enable max_parallel_downloads for DNF. Continuing...${RC}"
elif [ -f /etc/zypp/zypp.conf ] && ! grep -q '^multiversion' /etc/zypp/zypp.conf; then
    "$ESCALATION_TOOL" sed -i 's/^# download.use_deltarpm = true/download.use_deltarpm = true/' /etc/zypp/zypp.conf || printf "%b\n" "${YELLOW}Failed to enable parallel downloads for Zypper. Continuing...${RC}"
fi

echo "-------------------------------------------------------------------------"
echo "                    Installing Graphics Drivers"
echo "-------------------------------------------------------------------------"

# Detect GPU Type
gpu_type=$(lspci | grep -E "VGA|3D" || echo "No GPU detected")

# Function to install packages based on OS
install_gpu_packages() {
    noninteractive $1
}

# Graphics Drivers installation
if echo "${gpu_type}" | grep -qE "NVIDIA|GeForce"; then
    echo "Detected NVIDIA GPU"
    case "$DTYPE" in
        arch)
            if [ -e /proc/version ]; then
                [[ $(uname -r) == *lts* ]] && nvidia_pkg="nvidia-lts" || nvidia_pkg="nvidia"
            else
                if pacman -Qq linux-lts &>/dev/null; then
                    nvidia_pkg="nvidia-lts"
                else
                    nvidia_pkg="nvidia"
                fi
            fi
            install_gpu_packages "$nvidia_pkg nvidia-settings"
            ;;
        debian)
            debian_version=$(grep -oP '(?<=VERSION_CODENAME=).+' /etc/os-release)
            case $debian_version in
                bookworm|bullseye)
                    "$ESCALATION_TOOL" sed -i 's/main$/main contrib non-free non-free-firmware/' /etc/apt/sources.list
                    if command -v nala &> /dev/null; then
                        "$ESCALATION_TOOL" sed -i 's/main$/main contrib non-free non-free-firmware/' /etc/apt/sources.list.d/nala-sources.list
                    fi
                    if command -v nala &> /dev/null; then
                        "$ESCALATION_TOOL" nala update
                    else
                        "$ESCALATION_TOOL" apt update
                    fi
                    install_gpu_packages "nvidia-driver firmware-misc-nonfree"
                    ;;
                *) echo "Unsupported Debian version. Skipping NVIDIA driver installation."; return ;;
            esac
            ;;
        ubuntu)
            "$ESCALATION_TOOL" apt update
            if [[ "$1" == "--gpgpu" ]]; then
                install_gpu_packages "nvidia-driver-535-server nvidia-utils-535-server nvidia-cuda-toolkit"
            else
                if command -v ubuntu-drivers &> /dev/null; then
                    "$ESCALATION_TOOL" ubuntu-drivers autoinstall
                else
                    install_gpu_packages "nvidia-driver-535"
                fi
            fi
            ;;
        fedora)
            install_gpu_packages "kernel-devel kernel-headers gcc make dkms acpid libglvnd-glx libglvnd-opengl libglvnd-devel pkgconfig"
            if ! "$ESCALATION_TOOL" dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm; then
                echo "Failed to add RPM Fusion repositories. Exiting."
                return 1
            fi
            "$ESCALATION_TOOL" dnf makecache
            install_gpu_packages "akmod-nvidia xorg-x11-drv-nvidia-cuda"
            "$ESCALATION_TOOL" dracut --force
            echo "NVIDIA drivers installed. Please reboot your system to complete the installation."
            ;;
        opensuse-tumbleweed)
            if ! yes | "$ESCALATION_TOOL" zypper --non-interactive addrepo --refresh https://download.nvidia.com/opensuse/tumbleweed/ NVIDIA; then
                echo "Failed to add NVIDIA repository. Exiting."
                return 1
            fi
            yes | "$ESCALATION_TOOL" zypper --non-interactive --gpg-auto-import-keys refresh
            install_gpu_packages "nvidia-glG06 nvidia-computeG06 nvidia-gfxG06-kmp-default"
            ;;
        opensuse-leap)
            leap_version=$(grep VERSION_ID /etc/os-release | cut -d '"' -f 2)
            if ! yes | "$ESCALATION_TOOL" zypper --non-interactive addrepo --refresh "https://download.nvidia.com/opensuse/leap/$leap_version/" NVIDIA; then
                echo "Failed to add NVIDIA repository. Exiting."
                return 1
            fi
            yes | "$ESCALATION_TOOL" zypper --non-interactive --gpg-auto-import-keys refresh
            install_gpu_packages "nvidia-glG06 nvidia-computeG06 nvidia-gfxG06-kmp-default"
            ;;
    esac
    reboot_required=true
elif echo "${gpu_type}" | grep -qE "Radeon|AMD"; then
    echo "Detected AMD GPU"
    case "$DTYPE" in
        arch) install_gpu_packages "mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon libva-mesa-driver libva-utils" ;;
        debian)
            "$ESCALATION_TOOL" sed -i 's/main$/main contrib non-free non-free-firmware/' /etc/apt/sources.list
            "$ESCALATION_TOOL" apt update
            install_gpu_packages "firmware-amd-graphics libgl1-mesa-dri libglx-mesa0 mesa-vulkan-drivers xserver-xorg-video-all"
            ;;
        ubuntu)
            "$ESCALATION_TOOL" add-apt-repository ppa:kisak/kisak-mesa -y
            "$ESCALATION_TOOL" apt update
            install_gpu_packages "mesa-vulkan-drivers mesa-vdpau-drivers libdrm-amdgpu1 xserver-xorg-video-amdgpu"
            echo 'Section "Device"\n    Identifier "AMD"\n    Driver "amdgpu"\n    Option "DRI" "3"\nEndSection' | "$ESCALATION_TOOL" tee /etc/X11/xorg.conf.d/20-amdgpu.conf
            "$ESCALATION_TOOL" update-initramfs -u
            ;;
        fedora)
            install_gpu_packages "mesa-dri-drivers mesa-vulkan-drivers xorg-x11-drv-amdgpu"
            echo 'Section "Device"\n    Identifier "AMD"\n    Driver "amdgpu"\n    Option "DRI" "3"\nEndSection' | "$ESCALATION_TOOL" tee /etc/X11/xorg.conf.d/20-amdgpu.conf
            "$ESCALATION_TOOL" dracut --force
            ;;
        opensuse-tumbleweed|opensuse-leap)
            install_gpu_packages "xf86-video-amdgpu"
            ;;
    esac
    reboot_required=true
elif echo "${gpu_type}" | grep -qE "Intel"; then
    echo "Detected Intel GPU"
    case "$DTYPE" in
        arch) install_gpu_packages "libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-utils lib32-mesa" ;;
        debian|ubuntu) install_gpu_packages "intel-media-va-driver i965-va-driver vainfo mesa-vulkan-drivers" ;;
        fedora) install_gpu_packages "intel-media-driver mesa-va-drivers mesa-vdpau-drivers mesa-vulkan-drivers libva-intel-driver" ;;
        opensuse-tumbleweed|opensuse-leap)
            install_gpu_packages "xf86-video-intel"
            ;;
    esac
    reboot_required=true
else
    echo "No supported GPU found or GPU detection failed. Continuing without GPU driver installation..."
fi

echo "-------------------------------------------------------------------------"
echo "                Installing Applications and Network Manager              "
echo "-------------------------------------------------------------------------"

# Install EPEL for Rocky and AlmaLinux
if [ "$DTYPE" = "rocky" ] || [ "$DTYPE" = "almalinux" ]; then
    "$ESCALATION_TOOL" dnf install -y epel-release
fi

# Install common packages
common_packages="nano git wget btop ncdu qemu-guest-agent unzip"
for package in $common_packages; do
    install_package $package
done

# OS-specific packages including NetworkManager
case "$DTYPE" in
    arch) install_package "networkmanager" "terminus-font" "yazi" "openssh" ;;
    debian)
        install_package "network-manager" "console-setup" "xfonts-terminus" "openssh-server"
        # Stop and disable networking service
        "$ESCALATION_TOOL" systemctl stop networking
        "$ESCALATION_TOOL" systemctl disable networking
        # Modify /etc/network/interfaces
        "$ESCALATION_TOOL" cp /etc/network/interfaces /etc/network/interfaces.backup
        echo -e "# This file describes the network interfaces available on your system\n# and how to activate them. For more information, see interfaces(5).\n\nauto lo\niface lo inet loopback" | "$ESCALATION_TOOL" tee /etc/network/interfaces > /dev/null
        printf "%b\n" "${GREEN}Networking configuration updated for Debian${RC}"
        ;;
    ubuntu) install_package "network-manager" "console-setup" "xfonts-terminus" "openssh-server" ;;
    fedora|rocky|almalinux) install_package "NetworkManager-tui" "terminus-fonts-console" "openssh-server" ;;
    opensuse-tumbleweed|opensuse-leap) install_package "NetworkManager" "terminus-bitmap-fonts" "openssh" ;;
    alpine) install_package "networkmanager" "terminus-font" "openssh" ;;
esac

# Instead of using an array, let's use a simple space-separated string
if [ -f /etc/alpine-release ]; then
    services="networkmanager qemu-guest-agent"
else
    services="NetworkManager qemu-guest-agent"
fi

# Add SSH service based on system
if [ -e /usr/lib/systemd/system/sshd.service ] || [ -e /etc/init.d/sshd ]; then
    services="$services sshd"
elif [ -e /usr/lib/systemd/system/ssh.service ] || [ -e /etc/init.d/ssh ]; then
    services="$services ssh"
fi

# Enable and start services
for service in $services; do
    if isServiceActive "$service"; then
        printf "%b\n" "${GREEN}$service is already running${RC}"
    else
        printf "%b\n" "${CYAN}Enabling and starting $service...${RC}"
        if startAndEnableService "$service"; then
            printf "%b\n" "${GREEN}$service enabled and started${RC}"
        else
            printf "%b\n" "${YELLOW}Failed to enable/start $service. It may start on next boot.${RC}"
        fi
    fi
done

printf "%b\n" "${GREEN}Services processed. Some may require a system reboot to start properly.${RC}"

echo "-------------------------------------------------------------------------"
echo "                    Setting Permanent Console Font"
echo "-------------------------------------------------------------------------"

# Function to set console font
set_console_font() {
    if "$ESCALATION_TOOL" setfont ter-v18b; then
        echo "FONT=ter-v18b" | "$ESCALATION_TOOL" tee /etc/vconsole.conf > /dev/null
        printf "%b\n" "${GREEN}Console font set to ter-v18b${RC}"
    else
        printf "%b\n" "${YELLOW}Failed to set font ter-v18b. Using system default.${RC}"
        return 1
    fi
}

# Set permanent console font
case "$DTYPE" in
    arch|fedora|rocky|almalinux|opensuse-tumbleweed|opensuse-leap|alpine)
        if command -v setfont >/dev/null 2>&1; then
            if ! set_console_font; then
                printf "%b\n" "${YELLOW}Font setting failed. Check if terminus-font package is installed.${RC}"
            fi
        else
            printf "%b\n" "${YELLOW}setfont command not found. Console font setting may not be supported.${RC}"
        fi
        ;;
    debian|ubuntu)
        "$ESCALATION_TOOL" sed -i 's/^FONTFACE=.*/FONTFACE="TerminusBold"/' /etc/default/console-setup
        "$ESCALATION_TOOL" sed -i 's/^FONTSIZE=.*/FONTSIZE="24x12"/' /etc/default/console-setup
        "$ESCALATION_TOOL" DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -f noninteractive console-setup
        "$ESCALATION_TOOL" update-initramfs -u
        # Apply the font changes immediately
        if command -v setupcon >/dev/null 2>&1; then
            "$ESCALATION_TOOL" setupcon --force
            printf "%b\n" "${GREEN}Console font settings applied immediately.${RC}"
        else
            printf "%b\n" "${YELLOW}setupcon command not found. Font changes will apply after reboot.${RC}"
        fi
        printf "%b\n" "${GREEN}Console font settings configured for Debian/Ubuntu.${RC}"
        ;;
esac

printf "%b\n" "${GREEN}Console font settings have been configured and should persist after reboot.${RC}"

echo "-------------------------------------------------------------------------"
echo "                        Installation Complete                            "
echo "-------------------------------------------------------------------------"

if [ "$reboot_required" = true ]; then
    printf "%b\n" "${YELLOW}Rebooting the system in 10 seconds due to driver installations...${RC}"
    sleep 10
    "$ESCALATION_TOOL" reboot
else
    printf "%b\n" "${GREEN}No reboot required. All changes have been applied.${RC}"
fi