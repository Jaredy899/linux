#!/bin/sh -e

# Set SKIP_AUR_CHECK to ignore AUR helper check
SKIP_AUR_CHECK=true

# Source the common script directly from GitHub
eval "$(curl -s https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/common_script.sh)"
eval "$(curl -s https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/common_service_script.sh)"
# Run the environment check
checkEnv || exit 1

reboot_required=false

# Detect timezone
detected_timezone="$(curl --fail https://ipapi.co/timezone)"
if [ -n "$detected_timezone" ]; then
    printf "%b\n" "${CYAN}Detected timezone: $detected_timezone${RC}"
    if [ -e /usr/bin/timedatectl ]; then
        "$ESCALATION_TOOL" timedatectl set-timezone "$detected_timezone" || printf "%b\n" "${YELLOW}Failed to set timezone. This may be due to running in a chroot environment.${RC}"
    else
        "$ESCALATION_TOOL" ln -sf "/usr/share/zoneinfo/$detected_timezone" /etc/localtime
    fi
    printf "%b\n" "${GREEN}Timezone set to $detected_timezone${RC}"
else
    printf "%b\n" "${YELLOW}Failed to detect timezone. Please set it manually if needed.${RC}"
fi

# Function to replace NixOS configuration
replace_nixos_config() {
    if [ "$DTYPE" = "nixos" ]; then
        printf "%b\n" "${YELLOW}Replacing NixOS configuration...${RC}"
        "$ESCALATION_TOOL" curl -sSfL -o "/etc/nixos/configuration.nix" "https://raw.githubusercontent.com/Jaredy899/linux/main/config_changes/configuration.nix"
        printf "%b\n" "${YELLOW}Rebuilding NixOS...${RC}"
        "$ESCALATION_TOOL" nixos-rebuild switch
        printf "%b\n" "${GREEN}NixOS configuration replaced and rebuilt successfully.${RC}"
        exit 0
    fi
}

# Replace NixOS configuration if applicable and exit if it's NixOS
replace_nixos_config

# Function to install and configure Nala
install_nala() {
    printf "%b\n" "${CYAN}Checking if Nala should be installed...${RC}"
    if [ "$PACKAGER" = "apt-get" ]; then
        printf "%b\n" "${CYAN}Installing Nala...${RC}"
        if "$ESCALATION_TOOL" DEBIAN_FRONTEND=noninteractive apt-get update && "$ESCALATION_TOOL" apt-get install -y nala; then
            yes | "$ESCALATION_TOOL" nala fetch --auto --fetches 1 || printf "%b\n" "${YELLOW}Nala fetch failed, continuing...${RC}"
            printf "%b\n" "${GREEN}Nala has been installed.${RC}"
            PACKAGER="apt-get"
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

# Install EPEL for Rocky, AlmaLinux, and Oracle Linux
if [ "$DTYPE" = "rocky" ] || [ "$DTYPE" = "almalinux" ] || [ "$DTYPE" = "ol" ]; then
    printf "%b\n" "${CYAN}Installing EPEL repository...${RC}"
    "$ESCALATION_TOOL" "$PACKAGER" install -y epel-release || {
        printf "%b\n" "${RED}Failed to install EPEL repository. Continuing...${RC}"
    }
fi

# Install all required packages based on distribution
printf "%b\n" "${CYAN}Installing packages...${RC}"
case "$PACKAGER" in
    pacman)
        "$ESCALATION_TOOL" "$PACKAGER" -S --noconfirm --needed nano git wget btop ncdu qemu-guest-agent unzip terminus-font yazi
        ;;
    apt-get|nala)
        "$ESCALATION_TOOL" "$PACKAGER" install -y nano git wget btop ncdu qemu-guest-agent unzip openssh-server console-setup xfonts-terminus
        ;;
    dnf)
        "$ESCALATION_TOOL" "$PACKAGER" install -y nano git wget btop ncdu qemu-guest-agent unzip openssh-server terminus-fonts-console
        ;;
    zypper)
        "$ESCALATION_TOOL" "$PACKAGER" install -y nano git wget btop ncdu qemu-guest-agent unzip openssh terminus-bitmap-fonts
        ;;
    apk)
        "$ESCALATION_TOOL" "$PACKAGER" add --no-cache nano git wget btop ncdu qemu-guest-agent unzip openssh shadow font-terminus
        ;;
    eopkg)
        "$ESCALATION_TOOL" "$PACKAGER" install -y nano git wget btop ncdu qemu-guest-agent unzip openssh-server font-terminus-console
        ;;
    xbps-install)
        "$ESCALATION_TOOL" "$PACKAGER" -Sy nano git wget btop ncdu qemu-guest-agent unzip openssh terminus-font qemu-ga
        ;;
    slapt-get)
        "$ESCALATION_TOOL" "$PACKAGER" -y -i nano git wget btop ncdu qemu-guest-agent openssh terminus-font
        ;;
    *)
        printf "%b\n" "${YELLOW}Unknown package manager. Cannot install packages.${RC}"
        ;;
esac

# Set base services
services="qemu-guest-agent"
case "$PACKAGER" in
    xbps-install|slapt-get)
        services="qemu-ga"
        ;;
esac

# Add SSH service based on system
if [ -e /usr/lib/systemd/system/sshd.service ] || [ -e /etc/init.d/sshd ]; then
    services="$services sshd"
elif [ -e /usr/lib/systemd/system/ssh.service ] || [ -e /etc/init.d/ssh ]; then
    services="$services ssh"
fi

# Enable and start services
for service in $services; do
    if ! isServiceActive "$service"; then
        printf "%b\n" "${CYAN}Enabling and starting $service...${RC}"
        startAndEnableService "$service" && \
            printf "%b\n" "${GREEN}$service enabled and started${RC}" || \
            printf "%b\n" "${YELLOW}Failed to enable/start $service. It may start on next boot.${RC}"
    else
        printf "%b\n" "${GREEN}$service is already running${RC}"
    fi
done

# Configure firewall for SSH on openSUSE (moved outside the service loop)
if [ "$PACKAGER" = "zypper" ] && command -v firewall-cmd >/dev/null 2>&1; then
    printf "%b\n" "${CYAN}Enabling SSH in firewall...${RC}"
    "$ESCALATION_TOOL" firewall-cmd --permanent --add-service=ssh && \
    "$ESCALATION_TOOL" firewall-cmd --reload && \
        printf "%b\n" "${GREEN}SSH enabled in firewall${RC}" || \
        printf "%b\n" "${YELLOW}Failed to configure SSH in firewall${RC}"
fi

printf "%b\n" "${GREEN}Services processed. Some may require a system reboot to start properly.${RC}"

echo "-------------------------------------------------------------------------"
echo "                    Setting Permanent Console Font"
echo "-------------------------------------------------------------------------"

# Function to set console font
set_console_font() {
    if [ "$DTYPE" = "alpine" ]; then
        if "$ESCALATION_TOOL" setfont /usr/share/consolefonts/ter-v18b.psf.gz; then
            echo 'consolefont="ter-v18b.psf.gz"' | "$ESCALATION_TOOL" tee /etc/conf.d/consolefont > /dev/null
            "$ESCALATION_TOOL" rc-update add consolefont boot
            printf "%b\n" "${GREEN}Console font set to ter-v18b for Alpine Linux.${RC}"
        else
            printf "%b\n" "${YELLOW}Failed to set font ter-v18b. Using system default.${RC}"
            return 1
        fi
    else
        if "$ESCALATION_TOOL" setfont ter-v18b; then
            echo "FONT=ter-v18b" | "$ESCALATION_TOOL" tee /etc/vconsole.conf > /dev/null
            printf "%b\n" "${GREEN}Console font set to ter-v18b${RC}"
        else
            printf "%b\n" "${YELLOW}Failed to set font ter-v18b. Using system default.${RC}"
            return 1
        fi
    fi
}

# Set permanent console font
case "$DTYPE" in
    arch|fedora|rocky|almalinux|opensuse-*|alpine|void|salix)
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
echo "                    Enabling Serial Console (Proxmox)                   "
echo "-------------------------------------------------------------------------"

# Enable serial console for systemd systems
if command -v systemctl >/dev/null 2>&1; then
    "$ESCALATION_TOOL" systemctl enable getty@ttyS0.service
    printf "%b\n" "${GREEN}Enabled getty@ttyS0.service for serial console.${RC}"
fi

# Enable serial console for Alpine (OpenRC/BusyBox)
if [ "$DTYPE" = "alpine" ] && [ -f /etc/inittab ]; then
    if grep -q '^#ttyS0::respawn:/sbin/getty' /etc/inittab; then
        "$ESCALATION_TOOL" sed -i 's/^#\(ttyS0::respawn:\/sbin\/getty.*\)/\1/' /etc/inittab
        printf "%b\n" "${GREEN}Uncommented ttyS0::respawn in /etc/inittab for Alpine serial console.${RC}"
        reboot_required=true
    else
        printf "%b\n" "${YELLOW}ttyS0::respawn already enabled in /etc/inittab or not present.${RC}"
    fi
fi

# Add serial console to GRUB if present
if [ -f /etc/default/grub ]; then
    if ! grep -q 'console=ttyS0' /etc/default/grub; then
        "$ESCALATION_TOOL" sed -i 's/GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 console=tty0 console=ttyS0,115200"/' /etc/default/grub
        # Update GRUB
        if command -v update-grub >/dev/null 2>&1; then
            "$ESCALATION_TOOL" update-grub
        elif command -v grub2-mkconfig >/dev/null 2>&1; then
            "$ESCALATION_TOOL" grub2-mkconfig -o /boot/grub2/grub.cfg
        fi
        printf "%b\n" "${GREEN}Added serial console to GRUB and updated bootloader.${RC}"
        reboot_required=true
    else
        printf "%b\n" "${YELLOW}Serial console already present in GRUB config.${RC}"
    fi
fi

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
