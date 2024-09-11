#!/bin/bash

# Function to display the banner on each screen
function display_banner {
    echo -ne "
    -------------------------------------------------------------------------

                ███████╗███████╗██████╗  ██████╗ ██████╗  █████╗ 
                ██╔════╝██╔════╝██╔══██╗██╔═══██╗██╔══██╗██╔══██╗
                █████╗  █████╗  ██║  ██║██║   ██║██████╔╝███████║
                ██╔══╝  ██╔══╝  ██║  ██║██║   ██║██╔══██╗██╔══██║
                ██║     ███████╗██████╔╝╚██████╔╝██║  ██║██║  ██║
                ╚═╝     ╚══════╝╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝
    -------------------------------------------------------------------------
                        Automated Fedora Linux Installer
    -------------------------------------------------------------------------
    "
}

# Ask for username
clear
display_banner
read -p "Enter the username: " username

# Ask for hostname
clear
display_banner
read -p "Enter the hostname: " hostname

# Ask for password (with confirmation)
while true; do
    clear
    display_banner
    read -s -p "Enter the password: " password
    echo
    read -s -p "Confirm the password: " password_confirm
    echo
    if [ "$password" == "$password_confirm" ]; then
        break
    else
        echo "Passwords do not match. Please try again."
        sleep 2
    fi
done

# Ask for the disk to install Fedora on
clear
display_banner
lsblk
read -p "Enter the disk to install Fedora (e.g., /dev/sda): " disk

# Ask for the filesystem (XFS, ext4, Btrfs)
clear
display_banner
echo "Choose the filesystem to use:"
select fs in "xfs" "ext4" "btrfs"; do
    case $fs in
        xfs|ext4|btrfs)
            break
            ;;
        *)
            echo "Invalid choice. Please select xfs, ext4, or btrfs."
            ;;
    esac
done

# Create the Kickstart file dynamically based on the input
kickstart_file="/tmp/ks.cfg"

cat <<EOF > $kickstart_file
# System language
lang en_US.UTF-8

# Keyboard layout
keyboard us

# Timezone (automatically set to UTC)
timezone UTC --isUtc

# Root password (hashed with openssl)
rootpw --plaintext $password

# Network settings (DHCP for eth0)
network --bootproto=dhcp --device=eth0 --activate

# Hostname
network --hostname=$hostname

# Bootloader configuration
bootloader --location=mbr --boot-drive=${disk}

# Partitioning
clearpart --all --initlabel
part /boot --fstype="xfs" --size=1024
EOF

# Btrfs-specific partitioning
if [ "$fs" == "btrfs" ]; then
cat <<EOF >> $kickstart_file
part / --fstype="btrfs" --size=10240 --grow
btrfs / --label=FedoraBtrfs --data=single --metadata=single
btrfs /home --subvol --name=home
btrfs /var --subvol --name=var
EOF
else
# XFS or EXT4 partitioning
cat <<EOF >> $kickstart_file
part / --fstype="$fs" --size=10240 --grow
EOF
fi

cat <<EOF >> $kickstart_file
logvol swap --fstype="swap" --name=swap --vgname=VolGroup --size=2048

# User setup
user --name=$username --password=$password --plaintext --groups=wheel

# Reboot after installation
reboot

# Package selection
%packages
@^minimal-environment
wget
vim
%end

# Post-installation script
%post
echo "Installation completed on \$(date)" > /var/log/kickstart_post.log
%end
EOF

# Start the installation using the generated Kickstart file
clear
display_banner
echo "Starting Fedora installation using Kickstart..."
sleep 2
sudo dnf install -y anaconda  # Ensure the installer is present
sudo anaconda --kickstart=$kickstart_file
