#!/bin/bash

# Initialize error log
ERROR_LOG="/tmp/install_script_errors.log"
> "$ERROR_LOG"

# Function to log errors
log_error() {
    echo "$(date): $1" >> "$ERROR_LOG"
    echo "Error: $1" >&2
}

# Function to run a command and log any errors
run_command() {
    if ! "$@"; then
        log_error "Command failed: $*"
        return 1
    fi
}

set -o pipefail  # Ensure pipe failures are caught

reboot_required=false

# Function to detect the package manager
detect_package_manager() {
    if command -v apt-get &> /dev/null; then
        PACKAGE_MANAGER="apt-get"
        PACKAGE_INSTALL="install -y"
        PACKAGE_CHECK="dpkg -s"
        SUDO_GROUP="sudo"
        OS="debian"  # This covers both Debian and Ubuntu
    elif command -v dnf &> /dev/null; then
        PACKAGE_MANAGER="dnf"
        PACKAGE_INSTALL="install -y"
        PACKAGE_CHECK="rpm -q"
        SUDO_GROUP="wheel"
        OS="fedora"
    # ... (other package manager detections remain unchanged)
    else
        log_error "Unsupported package manager. Exiting."
        exit 1
    fi
}

# Detect package manager
detect_package_manager

echo "Detected package manager: $PACKAGE_MANAGER"
echo "Detected OS: $OS"

# Function to check if a package is installed
is_package_installed() {
    $PACKAGE_CHECK "$1" &> /dev/null
}

# Function to install a package if it's not already installed
install_package() {
    if ! is_package_installed "$1"; then
        echo "Installing $1..."
        if ! run_command sudo $PACKAGE_MANAGER $PACKAGE_INSTALL "$1"; then
            log_error "Failed to install $1"
            return 1
        fi
    else
        echo "$1 is already installed. Skipping."
    fi
}

# Install and configure Nala for Debian and Ubuntu
install_nala() {
    if [ "$OS" == "debian" ]; then
        if ! is_package_installed nala; then
            echo "Installing Nala on Debian/Ubuntu system..."
            run_command sudo $PACKAGE_MANAGER update
            run_command sudo $PACKAGE_MANAGER $PACKAGE_INSTALL nala -y
            
            # Configure nala
            run_command sudo nala fetch --auto --fetches 3
            echo "Nala installed and configured."
        else
            echo "Nala is already installed. Skipping."
        fi
        
        # Replace apt with nala
        PACKAGE_MANAGER="nala"
        PACKAGE_INSTALL="install"
        PACKAGE_CHECK="dpkg -s"

        # Make nala the default package manager
        echo "Configuring nala as the default package manager..."
        
        # Create aliases for apt commands
        run_command echo "alias apt='nala'" | sudo tee -a /etc/bash.bashrc > /dev/null
        run_command echo "alias apt-get='nala'" | sudo tee -a /etc/bash.bashrc > /dev/null
        run_command echo "alias aptitude='nala'" | sudo tee -a /etc/bash.bashrc > /dev/null

        # Create scripts to intercept apt commands
        run_command sudo tee /usr/local/bin/apt << EOF > /dev/null
#!/bin/sh
echo "apt has been replaced by nala. Running nala instead."
nala "\$@"
EOF
        run_command sudo chmod +x /usr/local/bin/apt

        run_command sudo tee /usr/local/bin/apt-get << EOF > /dev/null
#!/bin/sh
echo "apt-get has been replaced by nala. Running nala instead."
nala "\$@"
EOF
        run_command sudo chmod +x /usr/local/bin/apt-get

        echo "Nala has been set as the default package manager."
    fi
}

# Install Nala if on Debian/Ubuntu
install_nala

# Install package containing lspci
install_lspci() {
    case $OS in
        "debian"|"ubuntu"|"fedora"|"centos"|"arch"|"opensuse"|"alpine")
            install_package pciutils
            ;;
        "gentoo")
            install_package sys-apps/pciutils
            ;;
        *)
            log_error "Unable to install lspci. Please install it manually."
            return 1
            ;;
    esac
}

# Install lspci
install_lspci

# Detect GPU Type
gpu_type=$(lspci | grep -E "VGA|3D" || echo "No GPU detected")

# Function to install NVIDIA drivers on Fedora
install_nvidia_fedora() {
    echo "Setting up NVIDIA drivers for Fedora..."
    
    # Enable RPM Fusion repositories
    if ! rpm -q rpmfusion-free-release > /dev/null; then
        run_command sudo dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
    fi
    if ! rpm -q rpmfusion-nonfree-release > /dev/null; then
        run_command sudo dnf install -y https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
    fi
    
    # Update package list
    run_command sudo dnf update -y
    
    # Install NVIDIA driver
    if run_command sudo dnf install -y akmod-nvidia; then
        echo "NVIDIA drivers installed successfully."
    elif run_command sudo dnf install -y kmod-nvidia; then
        echo "NVIDIA drivers (kmod-nvidia) installed successfully."
    else
        log_error "Failed to install NVIDIA drivers. Please check your system configuration."
        echo "You may need to manually install the appropriate driver for your GPU."
        echo "Visit https://rpmfusion.org/Howto/NVIDIA for more information."
    fi
}

# Graphics Drivers installation based on OS and GPU type
if echo "${gpu_type}" | grep -E "NVIDIA|GeForce" > /dev/null; then
    echo "Detected NVIDIA GPU"
    case $OS in
        "arch")
            install_package nvidia
            install_package nvidia-settings
            ;;
        "debian"|"ubuntu")
            if [ "$OS" == "ubuntu" ]; then
                run_command sudo ubuntu-drivers autoinstall
            else
                # For Debian, we need to add non-free repository and install nvidia-driver
                echo "Setting up NVIDIA drivers for Debian..."
                
                # Check if non-free repository is enabled
                if ! grep -q "non-free" /etc/apt/sources.list; then
                    echo "Adding non-free repository..."
                    run_command sudo sed -i '/^deb/ s/$/ non-free/' /etc/apt/sources.list
                    run_command sudo $PACKAGE_MANAGER update
                fi
                
                # Install linux headers
                install_package linux-headers-$(uname -r)
                
                # Install NVIDIA drivers
                install_package nvidia-driver
                
                if ! is_package_installed nvidia-driver; then
                    log_error "Unable to install NVIDIA driver. Please check your system configuration."
                    echo "You may need to manually install the appropriate driver for your GPU."
                    echo "Visit https://wiki.debian.org/NvidiaGraphicsDrivers for more information."
                fi
            fi
            ;;
        "fedora"|"centos")
            install_nvidia_fedora
            ;;
        *)
            log_error "NVIDIA driver installation not configured for $OS"
            ;;
    esac
    reboot_required=true
elif echo "${gpu_type}" | grep 'VGA' | grep -E "Radeon|AMD" > /dev/null; then
    echo "Detected AMD GPU"
    case $OS in
        "arch")
            install_package xf86-video-amdgpu
            ;;
        "debian"|"ubuntu")
            install_package firmware-amd-graphics
            ;;
        "fedora"|"centos")
            install_package xorg-x11-drv-amdgpu
            ;;
        *)
            log_error "AMD driver installation not configured for $OS"
            ;;
    esac
    reboot_required=true
elif echo "${gpu_type}" | grep -E "Intel" > /dev/null; then
    echo "Detected Intel GPU"
    case $OS in
        "arch")
            install_package libva-intel-driver
            install_package libvdpau-va-gl
            install_package lib32-vulkan-intel
            install_package vulkan-intel
            install_package libva-utils
            install_package lib32-mesa
            ;;
        "debian"|"ubuntu")
            install_package intel-media-va-driver
            install_package mesa-va-drivers
            install_package mesa-vulkan-drivers
            ;;
        "fedora"|"centos")
            install_package intel-media-driver
            install_package mesa-vulkan-drivers
            ;;
        *)
            log_error "Intel driver installation not configured for $OS"
            ;;
    esac
    reboot_required=true
else
    log_error "No supported GPU found"
fi

# Install and enable NetworkManager
nstall_network_manager() {
    local package_name
    case $OS in
        "fedora"|"centos")
            package_name="NetworkManager"
            ;;
        *)
            package_name="networkmanager"
            ;;
    esac

    echo "Installing NetworkManager..."
    if install_package "$package_name"; then
        echo "NetworkManager installed successfully."
        
        # Enable and start NetworkManager
        if run_command sudo systemctl enable NetworkManager.service; then
            echo "NetworkManager enabled successfully."
            if run_command sudo systemctl start NetworkManager.service; then
                echo "NetworkManager started successfully."
            else
                log_error "Failed to start NetworkManager. You may need to start it manually after reboot."
            fi
        else
            log_error "Failed to enable NetworkManager. You may need to enable it manually after reboot."
        fi
    else
        log_error "Failed to install NetworkManager. You may need to install it manually."
    fi
}

# Install common applications
common_apps="nano git ncdu qemu-guest-agent wget"
for app in $common_apps; do
    install_package $app
done

case $OS in
    "arch")
        install_package terminus-font
        install_package yazi
        install_package timeshift
        ;;
    "debian"|"ubuntu")
        install_package console-setup
        install_package xfonts-terminus
        install_package timeshift
        ;;
    "fedora"|"centos")
        install_package terminus-fonts-console
        install_package timeshift
        ;;
    *)
        log_error "Some applications may not be available for $OS"
        ;;
esac

# Set permanent console font
case $OS in
    "arch"|"fedora"|"centos")
        echo "Setting console font to ter-v18b in /etc/vconsole.conf"
        if grep -q '^FONT=' /etc/vconsole.conf; then
            run_command sudo sed -i 's/^FONT=.*/FONT=ter-v18b/' /etc/vconsole.conf
        else
            run_command echo "FONT=ter-v18b" | sudo tee -a /etc/vconsole.conf > /dev/null
        fi
        run_command sudo setfont ter-v18b
        ;;
    "debian"|"ubuntu")
        echo "Setting console font to Terminus in /etc/default/console-setup"
        run_command sudo sed -i 's/^FONTFACE=.*/FONTFACE="Terminus"/' /etc/default/console-setup
        run_command sudo sed -i 's/^FONTSIZE=.*/FONTSIZE="18x10"/' /etc/default/console-setup
        run_command sudo update-initramfs -u
        run_command sudo setfont /usr/share/consolefonts/Uni2-TerminusBold18x10.psf.gz
        ;;
    *)
        log_error "Console font setting not configured for $OS"
        ;;
esac

# Install Cockpit
if ! is_package_installed cockpit; then
    echo "Installing Cockpit..."
    install_package cockpit
    run_command sudo systemctl enable --now cockpit.socket

    # Open firewall port for Cockpit (port 9090)
    if command -v ufw &> /dev/null; then
        run_command sudo ufw allow 9090/tcp
        run_command sudo ufw reload
    elif command -v firewall-cmd &> /dev/null; then
        run_command sudo firewall-cmd --permanent --add-service=cockpit
        run_command sudo firewall-cmd --reload
    else
        log_error "No firewall manager found. Skipping firewall configuration."
    fi

    echo "Cockpit installation complete. Access it via https://<your-server-ip>:9090"
else
    echo "Cockpit is already installed. Skipping installation."
fi

if [ "$reboot_required" = true ]; then
    echo "Rebooting the system in 5 seconds due to GPU driver installation..."
    sleep 5
    sudo reboot
else
    echo "No GPU drivers were installed, skipping reboot."
fi

echo "Script execution completed. Check $ERROR_LOG for any errors that occurred during the process."