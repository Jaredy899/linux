#!/bin/sh -e

# Set SKIP_AUR_CHECK to ignore AUR helper check
SKIP_AUR_CHECK=true

# Source the common script directly from GitHub
. <(curl -s https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/common_script.sh)
. <(curl -s https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/common_service_script.sh)

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
    alpine) install_package "networkmanager" "terminus-font" "openssh" "shadow" ;;
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