#!/bin/sh
# Source common functions
eval "$(curl -s https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/common_script.sh)"
eval "$(curl -s https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/common_service_script.sh)"

# Check environment and requirements
checkEnv

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

install_zig() {
    if ! command -v zig >/dev/null 2>&1; then
        printf "%b\n" "${YELLOW}Installing Zig ${ZIG_VERSION}...${RC}"
        
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

        if ! command -v zig >/dev/null 2>&1; then
            printf "%b\n" "${RED}Zig installation failed${RC}"
            exit 1
        fi
    fi
}

install_ghostty_binary() {
    printf "%b\n" "${CYAN}Attempting to install Ghostty from official binaries...${RC}"
    
    case "$PACKAGER" in
        "pacman")
            $ESCALATION_TOOL pacman -Syu ghostty
            ;;
        "emerge")
            $ESCALATION_TOOL emerge -av ghostty
            ;;
        "xbps-install")
            $ESCALATION_TOOL xbps-install -S ghostty
            ;;
        *)
            printf "%b\n" "${RED}No official binary installation method found for your distribution.${RC}"
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

install_dependencies() {
    printf "%b\n" "${CYAN}Installing dependencies for building Ghostty...${RC}"
    
    case "$PACKAGER" in
        "pacman")
            $ESCALATION_TOOL pacman -S --needed gtk4 libadwaita
            ;;
        "nala"|"apt")
            $ESCALATION_TOOL apt update
            $ESCALATION_TOOL apt install -y build-essential libgtk-4-dev libadwaita-1-dev git
            if grep -q "testing\|unstable" /etc/debian_version; then
                $ESCALATION_TOOL apt install -y gcc-multilib
            fi
            ;;
        "dnf")
            $ESCALATION_TOOL dnf install -y @development-tools gtk4-devel zig libadwaita-devel
            ;;
        "rpm-ostree")
            rpm-ostree install gtk4-devel zig libadwaita-devel
            ;;
        "emerge")
            $ESCALATION_TOOL emerge -av libadwaita gtk
            ;;
        "zypper")
            $ESCALATION_TOOL zypper install -y patterns-devel-base-devel_basis gtk4-tools libadwaita-devel pkgconf-pkg-config zig
            ;;
        "eopkg")
            $ESCALATION_TOOL eopkg install -c system.devel -y libgtk-4-devel libadwaita-devel perl-extutils-pkgconfig
            ;;
        "apk")
            $ESCALATION_TOOL apk add build-base gtk4.0-dev libadwaita-dev zig
            ;;
        *)
            printf "%b\n" "${RED}No dependency installation method found for your distribution.${RC}"
            return 1
            ;;
    esac
}

build_ghostty_from_source() {
    install_dependencies || return 1
    install_zig

    printf "%b\n" "${CYAN}Building Ghostty from source...${RC}"
    
    # Clone Ghostty repository
    git clone https://github.com/ghostty-org/ghostty.git
    cd ghostty

    # Build Ghostty
    $ESCALATION_TOOL zig build -p /usr -Doptimize=ReleaseFast

    printf "%b\n" "${GREEN}Ghostty has been built and installed successfully!${RC}"
}

# Main script logic
if install_ghostty_binary; then
    printf "%b\n" "${GREEN}Ghostty installed successfully from binaries!${RC}"
else
    printf "%b\n" "${YELLOW}Official binaries not available. Do you want to build Ghostty from source? (y/n)${RC}"
    read -r response
    if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
        build_ghostty_from_source
    else
        printf "%b\n" "${RED}Installation aborted.${RC}"
    fi
fi