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
            "$ESCALATION_TOOL" "$PACKAGER" -Syu
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
        flatpak update -y
    fi
}

checkEnv || exit 1
updateSystem
updateFlatpaks
