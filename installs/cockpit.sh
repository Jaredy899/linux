#!/bin/sh

# Source the common.sh script
GITHUB_BASE_URL="https://raw.githubusercontent.com/Jaredy899/linux/main"
COMMON_SCRIPT_URL="${GITHUB_BASE_URL}/common.sh"

# Download and source the common.sh script if it's not already present
if [ ! -f "common.sh" ]; then
    echo "Downloading common.sh..."
    curl -s -O "${COMMON_SCRIPT_URL}"
fi
source ./common.sh

# Run environment checks using common.sh
checkEnv

# Function to check if Cockpit is installed
is_cockpit_installed() {
    if command_exists cockpit; then
        echo "Cockpit is already installed."
        return 0
    else
        return 1
    fi
}

# Function to install Cockpit
install_cockpit() {
    echo "Installing Cockpit..."

    # Detect the Linux distribution using common.sh
    checkDistro
    DISTRO="$DTYPE"

    case "$DISTRO" in
        ubuntu|debian)
            $ESCALATION_TOOL $PACKAGER update -qq
            $ESCALATION_TOOL $PACKAGER install -y cockpit -qq
            ;;
        fedora|rocky|alma|centos|rhel)
            $ESCALATION_TOOL $PACKAGER install -y cockpit -q
            ;;
        arch)
            $ESCALATION_TOOL $PACKAGER -Sy cockpit --noconfirm >/dev/null
            ;;
        *)
            echo "Unsupported Linux distribution: $DISTRO"
            exit 1
            ;;
    esac

    # Start the Cockpit service if not already running
    if ! systemctl is-active --quiet cockpit; then
        $ESCALATION_TOOL systemctl enable --now cockpit.socket
        echo "Cockpit service has been started."
    else
        echo "Cockpit service is already running."
    fi

    # Open firewall port for Cockpit (port 9090) if UFW is installed
    if command_exists ufw; then
        $ESCALATION_TOOL ufw allow 9090/tcp
        $ESCALATION_TOOL ufw reload
        echo "UFW configuration updated to allow Cockpit."
    else
        echo "UFW is not installed. Please ensure port 9090 is open for Cockpit."
    fi

    echo "Cockpit installation complete."
    echo "You can access Cockpit via https://<your-server-ip>:9090"
}

# Check if Cockpit is already installed
if is_cockpit_installed; then
    echo "Cockpit is already installed. Skipping installation."
else
    install_cockpit
fi