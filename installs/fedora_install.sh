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
rootpw --iscrypted $(openssl passwd -6 $password)

# Network settings (DHCP for eth0)
network --bootproto=dhcp --device=eth0 --activate

# Hostname
network --hostname=$hostname

# Bootloader configuration
bootloader --location=mbr --boot-drive=${disk}

# Partitioning
clearpart --all --initlabel --drives=${disk}
part /boot --fstype="xfs" --size=1024 --ondisk=${disk}
EOF

# Btrfs-specific partitioning
if [ "$fs" == "btrfs" ]; then
cat <<EOF >> $kickstart_file
part btrfs.01 --fstype="btrfs" --grow --ondisk=${disk}
btrfs / --label=FedoraBtrfs --subvol --name=root btrfs.01
btrfs /home --subvol --name=home btrfs.01
btrfs /var --subvol --name=var btrfs.01
EOF
else
# XFS or EXT4 partitioning
cat <<EOF >> $kickstart_file
part / --fstype="$fs" --grow --ondisk=${disk}
EOF
fi

cat <<EOF >> $kickstart_file
part swap --fstype="swap" --size=2048 --ondisk=${disk}

# User setup
user --name=$username --password=$(openssl passwd -6 $password) --iscrypted --groups=wheel

# SELinux configuration
selinux --enforcing

# Firewall configuration
firewall --enabled --service=ssh

# Package selection
%packages
@^minimal-environment
wget
vim
%end

# Post-installation script
%post
echo "Installation completed on $(date)" > /var/log/kickstart_post.log
%end

# Reboot after installation
reboot
EOF

# Display the generated Kickstart file
clear
display_banner
echo "Generated Kickstart file:"
cat $kickstart_file

# Inform the user about next steps
echo
echo "Kickstart file has been generated at $kickstart_file"
echo "To use this Kickstart file during Fedora installation:"
echo "1. Boot into the Fedora installer"
echo "2. At the boot menu, press Tab to edit the boot options"
echo "3. Add 'inst.ks=file:/$kickstart_file' to the boot options"
echo "4. Press Enter to start the installation"

# Note: This script does not actually start the installation
# as that typically requires booting from installation media