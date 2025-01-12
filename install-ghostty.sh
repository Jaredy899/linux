#!/bin/bash

# Source common functions
eval "$(curl -s https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/common_script.sh)"
eval "$(curl -s https://raw.githubusercontent.com/Jaredy899/linux/refs/heads/main/common_service_script.sh)"

# Check environment and requirements
checkEnv

# Define variables
GHOSTTY_VERSION="latest"
# Set installation directory based on distribution
if [ "$PACKAGER" = "eopkg" ]; then
    INSTALL_DIR="/usr/bin"
    LIB_DIR="/usr/lib"
else
    INSTALL_DIR="/usr/local/bin"
    LIB_DIR="/usr/local/lib"
fi
ZIG_VERSION="0.13.0"

install_zig() {
    if ! command -v zig &> /dev/null; then
        printf "%b\n" "${YELLOW}Installing Zig ${ZIG_VERSION}...${RC}"
        
        # Determine Zig URL and directory based on architecture
        if [ "$ARCH" == "aarch64" ]; then
            ZIG_URL="https://ziglang.org/download/${ZIG_VERSION}/zig-linux-aarch64-${ZIG_VERSION}.tar.xz"
            ZIG_DIR="zig-linux-aarch64-${ZIG_VERSION}"
        else
            ZIG_URL="https://ziglang.org/download/${ZIG_VERSION}/zig-linux-x86_64-${ZIG_VERSION}.tar.xz"
            ZIG_DIR="zig-linux-x86_64-${ZIG_VERSION}"
        fi

        # Download and extract Zig
        curl -LO ${ZIG_URL}
        tar -xf ${ZIG_DIR}.tar.xz

        # Apply patch for aarch64
        if [ "$ARCH" == "aarch64" ]; then
            MEM_ZIG_PATH="${ZIG_DIR}/lib/std/mem.zig"
            if [ -f "$MEM_ZIG_PATH" ]; then
                sed -i 's/4 \* 1024/16 \* 1024/' "$MEM_ZIG_PATH"
            fi
        fi

        # Install Zig with distribution-specific paths
        "$ESCALATION_TOOL" mkdir -p "$LIB_DIR"
        "$ESCALATION_TOOL" mv ${ZIG_DIR} "$LIB_DIR/"
        "$ESCALATION_TOOL" ln -sf "$LIB_DIR/${ZIG_DIR}/zig" "$INSTALL_DIR/zig"
        rm ${ZIG_DIR}.tar.xz

        if ! command -v zig &> /dev/null; then
            printf "%b\n" "${RED}Zig installation failed${RC}"
            exit 1
        fi
    fi
}

install_binary_package() {
    case "$PACKAGER" in
        "pacman")
            printf "%b\n" "${CYAN}Installing Ghostty from official repositories...${RC}"
            noninteractive ghostty
            ;;
        "eopkg")
            printf "%b\n" "${CYAN}Installing Ghostty from repositories...${RC}"
            noninteractive ghostty
            ;;
        "xbps-install")
            printf "%b\n" "${CYAN}Installing Ghostty from repositories...${RC}"
            noninteractive ghostty
            ;;
        "dnf")
            printf "%b\n" "${YELLOW}Installing Ghostty from COPR repository...${RC}"
            "$ESCALATION_TOOL" dnf copr enable -y pgdev/ghostty
            noninteractive ghostty
            ;;
        *)
            return 1
            ;;
    esac
    return 0
}

install_from_source() {
    printf "%b\n" "${YELLOW}Installing Ghostty from source...${RC}"
    
    # Install dependencies based on package manager
    case "$PACKAGER" in
        "apt-get"|"nala")
            noninteractive libgtk-4-dev libadwaita-1-dev git
            ;;
        "pacman")
            noninteractive gtk4 libadwaita
            ;;
        "dnf")
            noninteractive gtk4-devel libadwaita-devel
            ;;
        "zypper")
            noninteractive gtk4-tools libadwaita-devel pkgconf-pkg-config
            ;;
        "eopkg")
            noninteractive -c system.devel libgtk-4-devel libadwaita-devel perl-extutils-pkgconfig
            ;;
        *)
            printf "%b\n" "${RED}Unsupported package manager for source installation${RC}"
            exit 1
            ;;
    esac

    # Install Zig if not present
    install_zig

    # Clone Ghostty repository
    git clone https://github.com/ghostty-org/ghostty.git
    cd ghostty

    # Build Ghostty
    printf "%b\n" "${CYAN}Building Ghostty...${RC}"
    zig build -p "$HOME/.local" -Doptimize=ReleaseFast

    printf "%b\n" "${GREEN}Ghostty has been built and installed successfully!${RC}"
}

function check_binary_availability() {
    case "$PACKAGER" in
        "pacman")
            if $AUR_HELPER -Ss "^ghostty$" >/dev/null 2>&1; then
                return 0
            fi
            ;;
        "eopkg")
            if eopkg list-available | grep -q "^ghostty$"; then
                return 0
            fi
            ;;
        "xbps-install")
            if xbps-query -Rs ghostty >/dev/null 2>&1; then
                return 0
            fi
            ;;
        "dnf")
            "$ESCALATION_TOOL" dnf copr enable -y pgdev/ghostty
            if dnf list ghostty >/dev/null 2>&1; then
                return 0
            fi
            ;;
        *)
            return 1
            ;;
    esac
    return 1
}

create_desktop_entry() {
    printf "%b\n" "${CYAN}Updating desktop entry...${RC}"
    
    DESKTOP_FILE="$HOME/.local/share/applications/com.mitchellh.ghostty.desktop"
    
    # Wait for desktop file to be created by build process
    if [ ! -f "$DESKTOP_FILE" ]; then
        printf "%b\n" "${RED}Desktop entry not found at $DESKTOP_FILE${RC}"
        return 1
    fi

    # Modify the Exec line for Raspberry Pi if needed
    if [ "$ARCH" = "aarch64" ]; then
        sed -i "s|^Exec=.*|Exec=env GDK_BACKEND=wayland,x11 LIBGL_ALWAYS_SOFTWARE=1 $HOME/.local/bin/ghostty|" "$DESKTOP_FILE"
    fi

    # Update desktop database for user
    if command_exists update-desktop-database; then
        update-desktop-database "$HOME/.local/share/applications"
    fi

    printf "%b\n" "${GREEN}Desktop entry updated successfully${RC}"
    printf "%b\n" "${YELLOW}Note: You may need to log out and back in to see the application in your menu${RC}"
}

# Main installation logic
printf "%b\n" "${CYAN}Checking for binary package availability...${RC}"

if check_binary_availability; then
    printf "%b\n" "${CYAN}Binary package found for Ghostty${RC}"
    install_binary_package
    printf "%b\n" "${GREEN}Ghostty has been installed successfully from package repository!${RC}"
else
    printf "%b\n" "${YELLOW}No binary package found for Ghostty.${RC}"
    if command -v zig >/dev/null 2>&1; then
        printf "%b\n" "${CYAN}Zig is already installed${RC}"
    else
        printf "%b\n" "${YELLOW}Zig binary not found.${RC}"
    fi
    
    printf "%b\n" "${YELLOW}Would you like to install Ghostty from source? (y/N)${RC}"
    read -r response
    if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
        if ! command -v zig >/dev/null 2>&1; then
            install_zig
        fi
        install_from_source
    else
        printf "%b\n" "${RED}Installation cancelled.${RC}"
        exit 1
    fi
fi

# Verify installation
if command -v ghostty &> /dev/null; then
    printf "%b\n" "${GREEN}Ghostty installation verified successfully!${RC}"
    ghostty --version
else
    printf "%b\n" "${RED}Ghostty installation could not be verified.${RC}"
    exit 1
fi 