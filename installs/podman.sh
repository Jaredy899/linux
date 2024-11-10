#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

echo "Installing Podman and related packages..."
pacman -S --needed podman podman-compose podman-docker linux-modules-extra netavark aardvark-dns

# Create the containers config directory if it doesn't exist
mkdir -p /etc/containers

# Create storage configuration for better BTRFS support
cat > /etc/containers/storage.conf << 'EOL'
[storage]
driver = "btrfs"
graphroot = "/var/lib/containers/storage"
runroot = "/run/containers/storage"
[storage.options]
mount_program = ""
EOL

# Add networking configuration
cat > /etc/containers/containers.conf << 'EOL'
[network]
network_backend = "netavark"
EOL

# Enable kernel modules on boot
echo "Enabling kernel modules on boot..."
cat > /etc/modules-load.d/podman.conf << 'EOL'
overlay
br_netfilter
bridge
EOL

# Configure required sysctl parameters
echo "Configuring sysctl parameters..."
cat > /etc/sysctl.d/podman.conf << 'EOL'
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOL

# Configure default registry
echo "Configuring container registry..."
mkdir -p /etc/containers/registries.conf.d
cat > /etc/containers/registries.conf.d/00-unqualified-search-registries.conf << 'EOL'
unqualified-search-registries = ["docker.io"]
EOL

# Enable the podman socket
systemctl enable podman.socket

echo "Installation complete!"
echo "Please restart your system for all changes to take effect."
echo "Note: For rootless mode, each user needs to run:"
echo "usermod --add-subuids 100000-165535 --add-subgids 100000-165535 USERNAME"
echo "Replace USERNAME with the actual username"