#!/bin/sh -e
# Source common functions
. ../../common-script.sh


# Define variables
GHOSTTY_VERSION="latest"
ZIG_VERSION="0.13.0"

INSTALL_DIR="/usr/local/bin"
LIB_DIR="/usr/local/lib"

installZig() {
    # Check if zig is installed
    if command -v zig >/dev/null 2>&1; then
        return 0
    fi

    printf "%b\n" "${YELLOW}Installing Zig...${RC}"
    
    # First try package manager installation
    case "$PACKAGER" in
        pacman)
            "$ESCALATION_TOOL" "$PACKAGER" -S --needed zig=0.13.0
            ;;
        dnf|eopkg)
            "$ESCALATION_TOOL" "$PACKAGER" install -y zig
            ;;
        zypper)
            if grep -q "Tumbleweed" /etc/os-release; then
                "$ESCALATION_TOOL" "$PACKAGER" install -y zig
            else
                PACKAGE_MANAGER_FAILED=true
            fi
            ;;
        apk)
            "$ESCALATION_TOOL" "$PACKAGER" add zig
            ;;
        xbps-install)
            "$ESCALATION_TOOL" "$PACKAGER" -S zig
            ;;
        *)
            PACKAGE_MANAGER_FAILED=true
            ;;
    esac

    # Fall back to manual installation if package manager failed
    if [ "${PACKAGE_MANAGER_FAILED:-}" = "true" ]; then
        printf "%b\n" "${YELLOW}No package manager installation available, installing Zig ${ZIG_VERSION} manually...${RC}"
        
        # Determine Zig URL and directory based on architecture
        if [ "$ARCH" = "aarch64" ]; then
            ZIG_URL="https://ziglang.org/download/${ZIG_VERSION}/zig-linux-aarch64-${ZIG_VERSION}.tar.xz"
            ZIG_DIR="zig-linux-aarch64-${ZIG_VERSION}"
        else
            ZIG_URL="https://ziglang.org/download/${ZIG_VERSION}/zig-linux-x86_64-${ZIG_VERSION}.tar.xz"
            ZIG_DIR="zig-linux-x86_64-${ZIG_VERSION}"
        fi

        # Download and extract Zig
        curl -LO "${ZIG_URL}"
        tar -xf "${ZIG_DIR}.tar.xz"

        # Apply patch for aarch64 on Raspberry Pi
        if [ "$ARCH" = "aarch64" ] && grep -q "Raspberry Pi" /proc/cpuinfo; then
            MEM_ZIG_PATH="${ZIG_DIR}/lib/std/mem.zig"
            if [ -f "$MEM_ZIG_PATH" ]; then
                sed -i 's/4 \* 1024/16 \* 1024/' "$MEM_ZIG_PATH"
            fi
        fi

        # Install Zig with distribution-specific paths
        "$ESCALATION_TOOL" mkdir -p "$LIB_DIR"
        "$ESCALATION_TOOL" mv "${ZIG_DIR}" "$LIB_DIR/"
        "$ESCALATION_TOOL" ln -sf "$LIB_DIR/${ZIG_DIR}/zig" "$INSTALL_DIR/zig"
        rm "${ZIG_DIR}.tar.xz"
    fi
}

installGhosttyBinary() {
    printf "%b\n" "${CYAN}Attempting to install Ghostty from official binaries...${RC}"
    
    case "$PACKAGER" in
        pacman)
            printf "%b\n" "-----------------------------------------------------"
            printf "%b\n" "Select the package to install:"
            printf "%b\n" "1. ${CYAN}ghostty${RC}      (stable release)"
            printf "%b\n" "2. ${CYAN}ghostty-git${RC}  (compiled from the latest commit)"
            printf "%b\n" "-----------------------------------------------------"
            printf "%b" "Enter your choice: "
            read -r choice
            case $choice in
                1) "$ESCALATION_TOOL" pacman -S --noconfirm ghostty ;;
                2) "$AUR_HELPER" -S --needed --noconfirm ghostty-git ;;
                *)
                    printf "%b\n" "${RED}Invalid choice:${RC} $choice"
                    return 1
                    ;;
            esac
            ;;
        xbps-install)
            "$ESCALATION_TOOL" "$PACKAGER" -Sy ghostty
            ;;
        zypper|eopkg)
            "$ESCALATION_TOOL" "$PACKAGER" install -y ghostty
            ;;
        *)
            return 1
            ;;
    esac

    if command -v ghostty >/dev/null 2>&1; then
        printf "%b\n" "${GREEN}Ghostty installed from binaries!${RC}"
        return 0
    else
        printf "%b\n" "${RED}Failed to install Ghostty from binaries.${RC}"
        return 1
    fi
}

installDependencies() {
    printf "%b\n" "${CYAN}Installing dependencies for building Ghostty...${RC}"
    
    case "$PACKAGER" in
        pacman)
            "$ESCALATION_TOOL" "$PACKAGER" -S --needed git gtk4 libadwaita
            ;;
        apt-get|nala)
            "$ESCALATION_TOOL" "$PACKAGER" update
            "$ESCALATION_TOOL" "$PACKAGER" install -y libgtk-4-dev libadwaita-1-dev git
            if grep -q "testing\|unstable" /etc/debian_version; then
                "$ESCALATION_TOOL" "$PACKAGER" install -y gcc-multilib
            fi
            ;;
        dnf)
            "$ESCALATION_TOOL" "$PACKAGER" install -y git gtk4-devel libadwaita-devel
            ;;
        zypper)
            "$ESCALATION_TOOL" "$PACKAGER" install -y git gtk4-devel libadwaita-devel pkgconf ncurses-devel
            ;;
        apk)
            "$ESCALATION_TOOL" "$PACKAGER" add icu-data-full icu-libs gtk4.0-dev git libadwaita-dev pkgconf ncurses
            ;;
        eopkg)
            "$ESCALATION_TOOL" "$PACKAGER" install -y git libgtk-4-devel libadwaita-devel pkgconf
            ;;
        *)
            printf "%b\n" "${RED}No dependency installation method found for your distribution.${RC}"
            return 1
            ;;
    esac
}

buildGhosttyFromSource() {
    installDependencies || return 1
    installZig

    printf "%b\n" "${CYAN}Building Ghostty from source...${RC}"
    
    git clone https://github.com/ghostty-org/ghostty.git
    cd ghostty
    # Try PATH first, fall back to full path if needed
    if command -v zig >/dev/null 2>&1; then
        "$ESCALATION_TOOL" zig build -p /usr -Doptimize=ReleaseFast
    else
        zig build -p /usr -Doptimize=ReleaseFast
    fi

    # Add special environment variables for Raspberry Pi OS
    if [ -f /etc/os-release ] && grep -q "Raspberry Pi OS" /etc/os-release; then
        if [ -f /usr/share/applications/com.mitchellh.ghostty.desktop ]; then
            "$ESCALATION_TOOL" sed -i 's|^\s*Exec=.*|Exec=env GDK_BACKEND=wayland,x11 LIBGL_ALWAYS_SOFTWARE=1 ghostty|' /usr/share/applications/com.mitchellh.ghostty.desktop
        fi
    fi

    printf "%b\n" "${GREEN}Ghostty has been built and installed successfully!${RC}"
}

installGhostty() {
    if command_exists ghostty; then
         printf "%b\n" "${GREEN}Ghostty is already installed!${RC}"
         exit 0
    fi

    printf "%b\n" "${CYAN}Attempting to install Ghostty...${RC}"
    
    if installGhosttyBinary; then
        printf "%b\n" "${GREEN}Ghostty installed successfully from binaries!${RC}"
        exit 0
    else
        printf "%b\n" "${YELLOW}Binary installation not available or failed.${RC}"
        printf "%b\n" "${YELLOW}Do you want to build Ghostty from source instead? (y/n)${RC}"
        read -r source_choice
        if [ "$source_choice" = "y" ] || [ "$source_choice" = "Y" ]; then
            buildGhosttyFromSource
        else
            exit 1
        fi
    fi
}

checkEnv
checkEscalationTool
checkAURHelper
installGhostty
