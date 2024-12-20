#!/bin/sh -e

# shellcheck disable=SC2034

RC='\033[0m'
RED='\033[31m'
YELLOW='\033[33m'
CYAN='\033[36m'
GREEN='\033[32m'
MAGENTA='\033[35m'

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

checkArch() {
    case "$(uname -m)" in
        x86_64 | amd64) ARCH="x86_64" ;;
        aarch64 | arm64) ARCH="aarch64" ;;
        *) printf "%b\n" "${RED}Unsupported architecture: $(uname -m)${RC}" && exit 1 ;;
    esac

    printf "%b\n" "${CYAN}System architecture: ${ARCH}${RC}"
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
            break
        fi
    done

    ## Enable apk community packages
    if [ "$PACKAGER" = "apk" ] && grep -qE '^#.*community' /etc/apk/repositories; then
        "$ESCALATION_TOOL" sed -i '/community/s/^#//' /etc/apk/repositories
        "$ESCALATION_TOOL" "$PACKAGER" update
    fi

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
    checkArch
    checkEscalationTool
    checkCommandRequirements "curl groups $ESCALATION_TOOL"
    checkPackageManager 'eopkg nala apt-get dnf pacman zypper apk'
    checkCurrentDirectoryWritable
    checkSuperUser
    checkDistro
    checkAURHelper
    setupNonInteractive
}

# Function to set up the non-interactive installation flags
setupNonInteractive() {
    case "$PACKAGER" in
        pacman)
            NONINTERACTIVE="--noconfirm --needed"
            ;;
        apt-get|nala|dnf|zypper)
            NONINTERACTIVE="-y"
            ;;
        apk)
            NONINTERACTIVE="--no-cache"
            ;;
        eopkg)
            NONINTERACTIVE="-y"
            ;;
        *)
            echo "Unsupported package manager: $PACKAGER"
            return 1
            ;;
    esac
}

# Unified package installation function
noninteractive() {
    if [ -z "$NONINTERACTIVE" ]; then
        setupNonInteractive
    fi
    case "$PACKAGER" in
        pacman)
            $ESCALATION_TOOL pacman -S --noconfirm --needed "$@"
            ;;
        apt-get|apt)
            $ESCALATION_TOOL apt-get install -y "$@"
            ;;
        apk)
            $ESCALATION_TOOL apk add --no-cache "$@"
            ;;
        eopkg)
            $ESCALATION_TOOL eopkg install -y "$@"
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
        apt-get|nala|dnf|zypper)
            echo "-y"
            ;;
        apk)
            echo "--no-cache"
            ;;
        eopkg)
            echo "-y"
            ;;
        *)
            echo ""  # Default to empty string if package manager is unknown
            ;;
    esac
}

# Update checkFlatpak to use noninteractive function
checkFlatpak() {
    if ! command_exists flatpak; then
        printf "%b\n" "${YELLOW}Installing Flatpak...${RC}"
        noninteractive flatpak
        printf "%b\n" "${YELLOW}Adding Flathub remote...${RC}"
        "$ESCALATION_TOOL" flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        printf "%b\n" "${YELLOW}Applications installed by Flatpak may not appear on your desktop until the user session is restarted...${RC}"
    else
        if ! flatpak remotes | grep -q "flathub"; then
            printf "%b\n" "${YELLOW}Adding Flathub remote...${RC}"
            "$ESCALATION_TOOL" flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        else
            printf "%b\n" "${CYAN}Flatpak is installed${RC}"
        fi
    fi
}

# Function to read keyboard input
read_key() {
    dd bs=1 count=1 2>/dev/null | od -An -tx1
}

# Function to show menu item
show_menu_item() {
    if [ "$selected" -eq "$1" ]; then
        printf "  ${GREEN}→ %s${RC}\n" "$3"
    else
        printf "    %s\n" "$3"
    fi
}

# Function to handle menu selection
handle_menu_selection() {
    selected=1
    total_options=$1
    saved_stty=$(stty -g)

    cleanup() {
        stty "$saved_stty"
        printf "\n${GREEN}Script terminated.${RC}\n"
        exit 0
    }

    trap cleanup INT

    while true; do
        # Clear screen and show header
        printf "\033[2J\033[H"
        printf "${CYAN}%s${RC}\n\n" "$2"

        # Call the function that displays menu items
        $3

        printf "\n${MAGENTA}Use arrow keys to navigate, Enter to select, q to quit${RC}\n"

        # Read keyboard input
        stty raw -echo
        char=$(read_key)
        case "$char" in
            " 71"|" 51") # 'q' or 'Q'
                stty "$saved_stty"
                cleanup
                ;;
            " 1b") # ESC or arrow keys
                char2=$(read_key)
                if [ "$char2" = " 5b" ]; then
                    char3=$(read_key)
                    case "$char3" in
                        " 41") # Up arrow
                            if [ $selected -eq 1 ]; then
                                selected=$total_options  # Wrap to bottom
                            else
                                selected=$((selected - 1))
                            fi
                            ;;
                        " 42") # Down arrow
                            if [ $selected -eq $total_options ]; then
                                selected=1  # Wrap to top
                            else
                                selected=$((selected + 1))
                            fi
                            ;;
                    esac
                fi
                ;;
            " 03") # Ctrl+C
                stty "$saved_stty"
                cleanup
                ;;
            " 0a"|" 0d") # Enter
                stty "$saved_stty"
                return $selected
                ;;
        esac
        stty "$saved_stty"
    done
}
