#!/bin/sh -e

# Source the common script
eval "$(curl -s https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/common_script.sh)"
eval "$(curl -s https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/common_service_script.sh)"

updateSystem() {
    printf "%b\n" "${YELLOW}Updating system packages.${RC}"
    case "$PACKAGER" in
        nala | apt-get | dnf | eopkg)
            "$ESCALATION_TOOL" "$PACKAGER" upgrade -y
            ;;
        pacman)
            "$ESCALATION_TOOL" "$PACKAGER" -Sy --noconfirm --needed archlinux-keyring
            "$AUR_HELPER" -Su --noconfirm
            ;;
        zypper)
            "$ESCALATION_TOOL" "$PACKAGER" --non-interactive dup
            ;;
        apk)
            "$ESCALATION_TOOL" "$PACKAGER" upgrade
            ;;
        xbps-install)
            "$ESCALATION_TOOL" "$PACKAGER" -Syu base-system
            ;;
        nix)
            "$ESCALATION_TOOL" nix-channel --update
            "$ESCALATION_TOOL" "$PACKAGER" -u '*'
            ;;
        *)
            printf "%b\n" "${RED}Unsupported package manager: ${PACKAGER}${RC}"
            exit 1
            ;;
    esac
}

updateFlatpaks() {
    if command_exists flatpak; then
        printf "%b\n" "${YELLOW}Updating flatpak packages.${RC}"
        "$ESCALATION_TOOL" flatpak update -y
    fi
}

enableParallelDownloads() {
    # Enable parallel downloads
    if [ -f /etc/pacman.conf ]; then
        "$ESCALATION_TOOL" sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf || printf "%b\n" "${YELLOW}Failed to enable ParallelDownloads for Pacman. Continuing...${RC}"
    elif [ -f /etc/dnf/dnf.conf ] && ! grep -q '^max_parallel_downloads' /etc/dnf/dnf.conf; then
        echo 'max_parallel_downloads=10' | "$ESCALATION_TOOL" tee -a /etc/dnf/dnf.conf || printf "%b\n" "${YELLOW}Failed to enable max_parallel_downloads for DNF. Continuing...${RC}"
    elif [ -f /etc/zypp/zypp.conf ] && ! grep -q '^multiversion' /etc/zypp/zypp.conf; then
        "$ESCALATION_TOOL" sed -i 's/^# download.use_deltarpm = true/download.use_deltarpm = true/' /etc/zypp/zypp.conf || printf "%b\n" "${YELLOW}Failed to enable parallel downloads for Zypper. Continuing...${RC}"
    fi
}

checkEnv || exit 1
enableParallelDownloads
updateSystem
updateFlatpaks
