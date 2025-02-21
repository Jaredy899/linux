#!/bin/sh -e

# shellcheck disable=SC2034

RC='\033[0m'
RED='\033[31m'
YELLOW='\033[33m'
CYAN='\033[36m'
GREEN='\033[32m'
MAGENTA='\033[35m'

command_exists() {
for cmd in "$@"; do
    export PATH="$HOME/.local/share/flatpak/exports/bin:/var/lib/flatpak/exports/bin:$PATH"
    command -v "$cmd" >/dev/null 2>&1 || return 1
done
return 0
}

checkFlatpak() {
    if ! command_exists flatpak; then
        printf "%b\n" "${YELLOW}Installing Flatpak...${RC}"
        case "$PACKAGER" in
            pacman)
                "$ESCALATION_TOOL" "$PACKAGER" -S --needed --noconfirm flatpak
                ;;
            apk)
                "$ESCALATION_TOOL" "$PACKAGER" add flatpak
                ;;
            *)
                "$ESCALATION_TOOL" "$PACKAGER" install -y flatpak
                ;;
        esac
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

checkArch() {
    case "$(uname -m)" in
        x86_64 | amd64) ARCH="x86_64" ;;
        aarch64 | arm64) ARCH="aarch64" ;;
        armv7l) ARCH="armv7l" ;;
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
        if [ "$(id -u)" = "0" ]; then
            ESCALATION_TOOL="eval"
            ESCALATION_TOOL_CHECKED=true
            printf "%b\n" "${CYAN}Running as root, no escalation needed${RC}"
            return 0
        fi

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

    ## Setup slapt-get and slapt-src
    if [ "$PACKAGER" = "slapt-get" ]; then
        if ! command_exists slapt-src; then
            printf "%b\n" "${YELLOW}Installing slapt-src and build dependencies...${RC}"
            $ESCALATION_TOOL slapt-get -i -y slapt-src cmake make gcc automake autoconf pkg-config libtool
        fi
        # Update slapt-src database
        printf "%b\n" "${CYAN}Updating slapt-src database...${RC}"
        $ESCALATION_TOOL slapt-src -u
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
            break
        fi
    done

    ## Check if member of the sudo group.
    if ! groups | grep -q "${SUGROUP}"; then
        printf "%b\n" "${RED}You need to be a member of the sudo group to run me!${RC}"
        exit 1
    fi
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
    checkPackageManager 'nala apt-get dnf pacman zypper apk xbps-install eopkg slapt-get'
    checkCurrentDirectoryWritable
    checkSuperUser
    checkDistro
    checkAURHelper
}

# Unified package installation function
noninteractive() {
    case $PACKAGER in
        pacman)
            $ESCALATION_TOOL $PACKAGER -S --noconfirm --needed "$@"
            ;;
        apt-get|nala|dnf|zypper|eopkg|xbps-install)
            $ESCALATION_TOOL $PACKAGER install -y "$@"
            ;;
        apk)
            $ESCALATION_TOOL $PACKAGER add --no-cache "$@"
            ;;
        slapt-get)
            $ESCALATION_TOOL $PACKAGER -y -i "$@"
            ;;
        *)
            echo "Unsupported package manager: $PACKAGER"
            return 1
            ;;
    esac
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

saved_stty=""
cleanup() {
    stty "$saved_stty"
    printf "\n${GREEN}Script terminated.${RC}\n"
    exit 0
}

# Function to handle menu selection
handle_menu_selection() {
    selected=1
    total_options=$1
    saved_stty=$(stty -g)

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
