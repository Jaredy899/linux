#!/bin/sh -e
# Source common functions
eval "$(curl -s https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/common_script.sh)"

# Define variables
GHOSTTY_VERSION="latest"
ZIG_VERSION="0.13.0"

# Set installation directory based on distribution
if [ "$PACKAGER" = "eopkg" ]; then
    INSTALL_DIR="/usr/bin"
    LIB_DIR="/usr/lib"
else
    INSTALL_DIR="/usr/local/bin"
    LIB_DIR="/usr/local/lib"
fi

installZig() {
    # Check if zig is installed and verify version
    if command -v zig >/dev/null 2>&1; then
        INSTALLED_ZIG_VERSION=$(zig version)
        if [ "$INSTALLED_ZIG_VERSION" = "0.13.0" ]; then
            return 0
        else
            printf "%b\n" "${YELLOW}Incorrect Zig version detected ($INSTALLED_ZIG_VERSION). Installing Zig 0.13.0...${RC}"
            # Remove existing zig if it exists in our install location
            if [ -L "$INSTALL_DIR/zig" ]; then
                "$ESCALATION_TOOL" rm "$INSTALL_DIR/zig"
            fi
        fi
    fi

    printf "%b\n" "${YELLOW}Installing Zig...${RC}"
    
    # First try package manager installation
    case "$PACKAGER" in
        pacman)
            "$ESCALATION_TOOL" pacman -S --needed zig=0.13.0
            ;;
        dnf|zypper|eopkg)
            "$ESCALATION_TOOL" "$PACKAGER" install -y zig
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

    # Verify version after package manager installation
    if [ "${PACKAGE_MANAGER_FAILED:-}" != "true" ] && command -v zig >/dev/null 2>&1; then
        INSTALLED_ZIG_VERSION=$(zig version)
        if [ "$INSTALLED_ZIG_VERSION" = "0.13.0" ]; then
            return 0
        else
            printf "%b\n" "${YELLOW}Package manager installed wrong Zig version. Falling back to manual installation...${RC}"
            case "$PACKAGER" in
                pacman)
                    "$ESCALATION_TOOL" pacman -R --noconfirm zig
                    ;;
                dnf|zypper|eopkg)
                    "$ESCALATION_TOOL" "$PACKAGER" remove -y zig
                    ;;
                apk)
                    "$ESCALATION_TOOL" "$PACKAGER" del zig
                    ;;
                xbps-install)
                    "$ESCALATION_TOOL" xbps-remove -R zig
                    ;;
            esac
        fi
    fi

    # Fall back to manual installation if package manager failed or installed wrong version
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
                1) "$ESCALATION_TOOL" pacman -S ghostty ;;
                2) "$AUR_HELPER" -S --needed --noconfirm ghostty-git ;;
                *)
                    printf "%b\n" "${RED}Invalid choice:${RC} $choice"
                    return 1
                    ;;
            esac
            ;;
        emerge)
            "$ESCALATION_TOOL" "$PACKAGER" -av ghostty
            ;;
        xbps-install)
            "$ESCALATION_TOOL" "$PACKAGER" -S ghostty
            ;;
        zypper)
            "$ESCALATION_TOOL" "$PACKAGER" install ghostty
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
            "$ESCALATION_TOOL" pacman -S --needed gtk4 libadwaita
            ;;
        nala|apt)
            "$ESCALATION_TOOL" apt update
            "$ESCALATION_TOOL" "$PACKAGER" install -y build-essential libgtk-4-dev libadwaita-1-dev git
            if grep -q "testing\|unstable" /etc/debian_version; then
                "$ESCALATION_TOOL" "$PACKAGER" install -y gcc-multilib
            fi
            ;;
        dnf)
            "$ESCALATION_TOOL" "$PACKAGER" install -y gtk4-devel libadwaita-devel
            ;;
        zypper)
            "$ESCALATION_TOOL" "$PACKAGER" install -y gtk4-devel libadwaita-devel pkgconf ncurses-devel
            ;;
        apk)
            "$ESCALATION_TOOL" "$PACKAGER" add gtk4.0-dev libadwaita-dev pkgconf ncurses
            ;;
        eopkg)
            "$ESCALATION_TOOL" "$PACKAGER" install -y libgtk-4-devel libadwaita-devel pkgconf
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

    printf "%b\n" "${GREEN}Ghostty has been built and installed successfully!${RC}"
}

installGhostty() {
    if installGhosttyBinary; then
        printf "%b\n" "${GREEN}Ghostty installed successfully from binaries!${RC}"
    else
        printf "%b\n" "${YELLOW}Official binaries not available. Do you want to build Ghostty from source? (y/n)${RC}"
        read -r response
        if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
            buildGhosttyFromSource
        else
            printf "%b\n" "${RED}Installation aborted.${RC}"
        fi
    fi
}

checkEnv
checkEscalationTool
checkAURHelper
installGhostty
