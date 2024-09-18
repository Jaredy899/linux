#!/bin/bash

set -e

# Function to display the banner
function display_banner {
    echo -ne "
    -------------------------------------------------------------------------
                         █████╗ ██████╗  ██████╗██╗  ██╗
                        ██╔══██╗██╔══██╗██╔════╝██║  ██║
                        ███████║██████╔╝██║     ███████║
                        ██╔══██║██╔══██╗██║     ██╔══██║ 
                        ██║  ██║██║  ██║╚██████╗██║  ██║ 
                        ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝ 
    -------------------------------------------------------------------------
                        Automated Arch Linux Installer
    -------------------------------------------------------------------------
    "
}

# Function to clear the screen and display the banner
function clear_with_banner {
    clear
    display_banner
}

# Install necessary packages
pacman -Sy --noconfirm --needed pacman-contrib terminus-font reflector curl reflector rsync grub
setfont ter-v18b
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup

clear_with_banner

# Function to handle disk selection
function select_disk {
    echo "Available disks:"
    mapfile -t DISKS < <(lsblk -d -n -p -o NAME,SIZE,MODEL | grep -E '(/dev/sd|/dev/nvme)')
    for i in "${!DISKS[@]}"; do
        echo "$((i+1)). ${DISKS[$i]}"
    done
    echo "Enter the number of the disk you want to use:"
    read DISK_NUMBER
    if ! [[ "$DISK_NUMBER" =~ ^[0-9]+$ ]] || [ "$DISK_NUMBER" -lt 1 ] || [ "$DISK_NUMBER" -gt "${#DISKS[@]}" ]; then
        echo "Invalid selection. Please try again."
        select_disk
    else
        DISK=$(echo "${DISKS[$DISK_NUMBER-1]}" | awk '{print $1}')
    fi
    export DISK
}

# Function to select filesystem
function select_filesystem {
    echo "Select filesystem:"
    FS_OPTIONS=("ext4" "btrfs" "xfs")
    for i in "${!FS_OPTIONS[@]}"; do
        echo "$((i+1)). ${FS_OPTIONS[$i]}"
    done
    read FS_NUMBER
    if ! [[ "$FS_NUMBER" =~ ^[0-9]+$ ]] || [ "$FS_NUMBER" -lt 1 ] || [ "$FS_NUMBER" -gt "${#FS_OPTIONS[@]}" ]; then
        echo "Invalid selection. Please try again."
        select_filesystem
    else
        FILESYSTEM=${FS_OPTIONS[$FS_NUMBER-1]}
    fi
    export FILESYSTEM
}

# Function to detect and confirm timezone
function detect_timezone {
    detected_timezone="$(curl --fail https://ipapi.co/timezone)"
    if [ $? -eq 0 ] && [ -n "$detected_timezone" ]; then
        echo "Detected timezone: $detected_timezone"
        echo "Is this correct? (y/n)"
        read confirm
        if [[ $confirm =~ ^[Yy]$ ]]; then
            TIMEZONE=$detected_timezone
        else
            select_timezone
        fi
    else
        echo "Unable to detect timezone automatically."
        select_timezone
    fi
    export TIMEZONE
}

# Function to search and select timezone (used if automatic detection is incorrect or fails)
function select_timezone {
    echo "Enter a search term for your timezone (e.g., 'New_York' or 'London'):"
    read SEARCH_TERM
    mapfile -t TIMEZONES < <(timedatectl list-timezones | grep -i "$SEARCH_TERM")
    if [ ${#TIMEZONES[@]} -eq 0 ]; then
        echo "No timezones found matching '$SEARCH_TERM'. Please try again."
        select_timezone
        return
    fi
    echo "Select your timezone:"
    for i in "${!TIMEZONES[@]}"; do
        echo "$((i+1)). ${TIMEZONES[$i]}"
    done
    read TZ_NUMBER
    if ! [[ "$TZ_NUMBER" =~ ^[0-9]+$ ]] || [ "$TZ_NUMBER" -lt 1 ] || [ "$TZ_NUMBER" -gt "${#TIMEZONES[@]}" ]; then
        echo "Invalid selection. Please try again."
        select_timezone
    else
        TIMEZONE=${TIMEZONES[$TZ_NUMBER-1]}
    fi
}

# Function to update mirrorlist using reflector
function update_mirrorlist {
    COUNTRY=$(curl --fail https://ipapi.co/country_name)
    if [ $? -eq 0 ] && [ -n "$COUNTRY" ]; then
        echo "Detected country: $COUNTRY"
        echo "Updating mirrorlist for $COUNTRY..."
        reflector --country "$COUNTRY" --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
        if [ $? -eq 0 ]; then
            echo "Mirrorlist updated successfully."
        else
            echo "Failed to update mirrorlist for $COUNTRY. Using default mirrorlist."
        fi
    else
        echo "Unable to detect country. Using default mirrorlist."
    fi
}

# Function to get user input
function get_user_input {
    echo "Enter username:"
    read USERNAME
    echo "Enter password:"
    read -s PASSWORD
    echo "Confirm password:"
    read -s PASSWORD_CONFIRM
    if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
        echo "Passwords do not match. Please try again."
        get_user_input
    fi
    echo "Enter hostname:"
    read HOSTNAME
    detect_timezone
}

# Main installation function
function install_arch {
    select_disk
    select_filesystem
    get_user_input
    update_mirrorlist

    # Unmount any partitions on the selected disk
    umount -R /mnt 2>/dev/null || true
    swapoff -a
    umount -R ${DISK}* 2>/dev/null || true

    # Partition the disk
    parted -s $DISK mklabel gpt
    parted -s $DISK mkpart primary fat32 1MiB 513MiB
    parted -s $DISK set 1 esp on
    parted -s $DISK mkpart primary $FILESYSTEM 513MiB 100%

    # Format partitions
    mkfs.fat -F32 ${DISK}1
    case $FILESYSTEM in
        ext4) mkfs.ext4 ${DISK}2 ;;
        btrfs) 
            mkfs.btrfs -f ${DISK}2
            mount ${DISK}2 /mnt
            btrfs subvolume create /mnt/@
            btrfs subvolume create /mnt/@home
            btrfs subvolume create /mnt/@snapshots
            btrfs subvolume create /mnt/@var_log
            umount /mnt
            mount -o subvol=@,compress=zstd,noatime ${DISK}2 /mnt
            mkdir -p /mnt/{home,.snapshots,var/log}
            mount -o subvol=@home,compress=zstd,noatime ${DISK}2 /mnt/home
            mount -o subvol=@snapshots,compress=zstd,noatime ${DISK}2 /mnt/.snapshots
            mount -o subvol=@var_log,compress=zstd,noatime ${DISK}2 /mnt/var/log
            ;;
        xfs) mkfs.xfs -f ${DISK}2 ;;
    esac

    # Mount boot partition
    mkdir -p /mnt/boot/efi
    mount ${DISK}1 /mnt/boot/efi

    # Install base system
    pacstrap /mnt base base-devel linux linux-firmware

    # Generate fstab
    genfstab -U /mnt >> /mnt/etc/fstab

    # If using BTRFS, update fstab with correct mount options
    if [ "$FILESYSTEM" == "btrfs" ]; then
        sed -i 's|subvol=@,|subvol=@,compress=zstd,noatime,|g' /mnt/etc/fstab
        sed -i 's|subvol=@home,|subvol=@home,compress=zstd,noatime,|g' /mnt/etc/fstab
        sed -i 's|subvol=@snapshots,|subvol=@snapshots,compress=zstd,noatime,|g' /mnt/etc/fstab
        sed -i 's|subvol=@var_log,|subvol=@var_log,compress=zstd,noatime,|g' /mnt/etc/fstab
    fi

    # Chroot and configure system
    arch-chroot /mnt /bin/bash << EOF
    # Set timezone
    ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
    hwclock --systohc

    # Set locale
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    locale-gen
    echo "LANG=en_US.UTF-8" > /etc/locale.conf

    # Set hostname
    echo $HOSTNAME > /etc/hostname

    # Set root password
    echo "root:$PASSWORD" | chpasswd

    # Create user
    useradd -m -G wheel -s /bin/bash $USERNAME
    echo "$USERNAME:$PASSWORD" | chpasswd

    # Configure sudo
    echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel

    # Install and configure bootloader (GRUB)
    pacman -S --noconfirm grub efibootmgr
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg

    # Enable network manager
    pacman -S --noconfirm networkmanager
    systemctl enable NetworkManager

    # Install and configure Timeshift
    pacman -S --noconfirm timeshift
    timeshift --btrfs
    timeshift --create --comments "Initial snapshot" --snapshot-device ${DISK}2

    # Exit chroot
    exit
EOF

    # Unmount partitions
    umount -R /mnt

    echo "Installation complete! You can now reboot into your new Arch Linux system."
}

# Run the installation
install_arch