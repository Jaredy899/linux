#!/bin/sh -e

# shellcheck disable=SC2034

RC='\033[0m'
RED='\033[31m'
YELLOW='\033[33m'
CYAN='\033[36m'
GREEN='\033[32m'

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

checkAURHelper() {
    ## Check & Install AUR helper
    if [ "$PACKAGER" = "pacman" ] && [ -z "$SKIP_AUR_CHECK" ]; then
        if [ -z "$AUR_HELPER_CHECKED" ]; then
            AUR_HELPERS="yay paru"
            for helper in ${AUR_HELPERS}; do
                if command_exists "${helper}"; then
                    AUR_HELPER=${helper}
                    printf "%b\n" "${CYAN}Using ${helper} as AUR helper${RC}"
                    AUR_HELPER_CHECKED=true
                    return 0
                fi
            done

            printf "%b\n" "${YELLOW}Installing yay as AUR helper...${RC}"
            "$ESCALATION_TOOL" "$PACKAGER" -S --needed --noconfirm base-devel
            cd /opt && "$ESCALATION_TOOL" git clone https://aur.archlinux.org/yay-bin.git && "$ESCALATION_TOOL" chown -R "$USER":"$USER" ./yay-bin
            cd yay-bin && makepkg --noconfirm -si

            if command_exists yay; then
                AUR_HELPER="yay"
                AUR_HELPER_CHECKED=true
            else
                printf "%b\n" "${RED}Failed to install AUR helper.${RC}"
                exit 1
            fi
        fi
    fi
}

checkEscalationTool() {
    ## Check for escalation tools.
    if [ -z "$ESCALATION_TOOL_CHECKED" ]; then
        ESCALATION_TOOLS='sudo doas'
        for tool in ${ESCALATION_TOOLS}; do
            if command_exists "${tool}"; then
                ESCALATION_TOOL=${tool}
                printf "%b\n" "${CYAN}Using ${tool} for privilege escalation${RC}"
                ESCALATION_TOOL_CHECKED=true
                return 0
            fi
        done

        printf "%b\n" "${RED}Can't find a supported escalation tool${RC}"
        exit 1
    fi
}

checkCommandRequirements() {
    ## Check for requirements.
    REQUIREMENTS=$1
    MISSING_REQS=""
    for req in ${REQUIREMENTS}; do
        if [ "$req" = "sudo" ] && [ "$PACKAGER" = "apk" ] && command_exists doas; then
            continue
        fi
        if ! command_exists "${req}"; then
            MISSING_REQS="$MISSING_REQS $req"
        fi
    done
    if [ -n "$MISSING_REQS" ]; then
        printf "%b\n" "${YELLOW}Missing requirements:${MISSING_REQS}${RC}"
        return 1
    fi
    return 0
}

checkPackageManager() {
    ## Check Package Manager
    PACKAGEMANAGER=$1
    for pgm in ${PACKAGEMANAGER}; do
        if command_exists "${pgm}"; then
            PACKAGER=${pgm}
            printf "%b\n" "${CYAN}Using ${pgm} as package manager${RC}"

            if [ "$PACKAGER" = "apk" ]; then
                if ! command_exists sudo; then
                    printf "%b\n" "${YELLOW}Installing sudo for Alpine Linux...${RC}"
                    su -c "apk update && apk add sudo"
                fi
            fi

            if [ $PACKAGER = 'nix-env' ] && [ -z "$NIXOS_CONFIG" ]; then
                NIXOS_CONFIG="/etc/nixos/configuration.nix"
                while [ ! -f "$NIXOS_CONFIG" ]; do
                    printf "%b\n" "${RED}configuration.nix not found.${RC}"
                    printf "%b" "${YELLOW}Enter the path manually: ${RC}"
                    read -r NIXOS_CONFIG
                done
            fi
            break
        fi
    done

    if [ -z "$PACKAGER" ]; then
        printf "%b\n" "${RED}Can't find a supported package manager${RC}"
        exit 1
    fi
}

checkSuperUser() {
    ## Check SuperUser Group
    SUPERUSERGROUP='wheel sudo root'
    for sug in ${SUPERUSERGROUP}; do
        if groups | grep -q "${sug}"; then
            SUGROUP=${sug}
            printf "%b\n" "${CYAN}Super user group ${SUGROUP}${RC}"
            return 0
        fi
    done

    printf "%b\n" "${YELLOW}You are not a member of a known superuser group.${RC}"
    return 1
}

checkCurrentDirectoryWritable() {
    ## Check if the current directory is writable.
    GITPATH="$(dirname "$(realpath "$0")")"
    if [ ! -w "$GITPATH" ]; then
        printf "%b\n" "${RED}Can't write to $GITPATH${RC}"
        exit 1
    fi
}

checkDistro() {
    DTYPE="unknown"  # Default to unknown
    # Use /etc/os-release for modern distro identification
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DTYPE=$ID
    fi
}

checkEnv() {
    local all_checks_passed=true

    if ! checkCommandRequirements 'curl groups sudo'; then
        all_checks_passed=false
    fi
    checkPackageManager 'nala apt-get dnf pacman zypper nix-env apk'
    checkCurrentDirectoryWritable
    if ! checkSuperUser; then
        all_checks_passed=false
    fi
    checkDistro
    checkEscalationTool
    checkAURHelper
    setupNonInteractive

    if [ "$all_checks_passed" = false ]; then
        return 1
    fi
    return 0
}

# Function to set up the non-interactive installation flags
setupNonInteractive() {
    case "$PACKAGER" in
        pacman)
            NONINTERACTIVE="--noconfirm --needed"
            ;;
        apk)
            NONINTERACTIVE="--no-interactive"
            ;;
        apt-get|nala|dnf|zypper)
            NONINTERACTIVE="-y"
            ;;
        *)
            echo "Unsupported package manager: $PACKAGER"
            return 1
            ;;
    esac
}

# Function to perform non-interactive package installation
noninteractive() {
    if [ -z "$NONINTERACTIVE" ]; then
        setupNonInteractive
    fi
    case "$PACKAGER" in
        apt-get|apt)
            $ESCALATION_TOOL $PACKAGER install $NONINTERACTIVE "$@"
            ;;
        pacman)
            $ESCALATION_TOOL $PACKAGER -S --noconfirm --needed "$@"
            ;;
        apk)
            $ESCALATION_TOOL $PACKAGER add $NONINTERACTIVE "$@"
            ;;
        *)
            $ESCALATION_TOOL $PACKAGER install $NONINTERACTIVE "$@"
            ;;
    esac
}

# Function to get non-interactive installation flags (if needed elsewhere)
getNonInteractiveFlags() {
    case "$PACKAGER" in
        pacman)
            echo "--noconfirm --needed"
            ;;
        apk)
            echo "--no-interactive"
            ;;
        apt-get|nala|dnf|zypper)
            echo "-y"
            ;;
        *)
            echo ""  # Default to empty string if package manager is unknown
            ;;
    esac
}
