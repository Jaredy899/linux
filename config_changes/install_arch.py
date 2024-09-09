from pathlib import Path
from archinstall import Installer, profile, disk, models
from archinstall.default_profiles.minimal import MinimalProfile
import requests
import subprocess
import os
import getpass

# Function to automatically detect the timezone
def get_timezone():
    try:
        response = requests.get("https://ipapi.co/timezone")
        return response.text.strip()
    except:
        return "UTC"  # Default to UTC if timezone can't be detected

# Function to clear the screen and display the banner
def clear_screen_with_banner():
    os.system('clear')
    print("""
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
    """)

# Ask the user for the desired filesystem
clear_screen_with_banner()
print("Choose filesystem:")
print("1) Btrfs")
print("2) ext4")
print("3) XFS")
fs_choice = input("Enter the number (1, 2, or 3): ")

# Determine the filesystem type based on user input
if fs_choice == "1":
    fs_type = disk.FilesystemType('btrfs')
elif fs_choice == "2":
    fs_type = disk.FilesystemType('ext4')
elif fs_choice == "3":
    fs_type = disk.FilesystemType('xfs')
else:
    print("Invalid choice, defaulting to ext4.")
    fs_type = disk.FilesystemType('ext4')

# Get the physical disk device
device_path = Path('/dev/sda')
device = disk.device_handler.get_device(device_path)
if not device:
    raise ValueError(f"No device found for path {device_path}")

# Disk modification configuration
device_modification = disk.DeviceModification(device, wipe=True)

# Create partitions
boot_partition = disk.PartitionModification(
    status=disk.ModificationStatus.Create,
    type=disk.PartitionType.Primary,
    start=disk.Size(1, disk.Unit.MiB, device.device_info.sector_size),
    length=disk.Size(512, disk.Unit.MiB, device.device_info.sector_size),
    mountpoint=Path('/boot'),
    fs_type=disk.FilesystemType.Fat32,
    flags=[disk.PartitionFlag.Boot]
)
device_modification.add_partition(boot_partition)

root_partition = disk.PartitionModification(
    status=disk.ModificationStatus.Create,
    type=disk.PartitionType.Primary,
    start=disk.Size(513, disk.Unit.MiB, device.device_info.sector_size),
    length=disk.Size(20, disk.Unit.GiB, device.device_info.sector_size),
    mountpoint=Path('/'),
    fs_type=fs_type,
    mount_options=[]
)
device_modification.add_partition(root_partition)

# Create the disk configuration
disk_config = disk.DiskLayoutConfiguration(
    config_type=disk.DiskLayoutType.Default,
    device_modifications=[device_modification]
)

# Filesystem handler to format and prepare disks
fs_handler = disk.FilesystemHandler(disk_config)
fs_handler.perform_filesystem_operations(show_countdown=False)

# Get the timezone automatically
clear_screen_with_banner()
timezone = get_timezone()
print(f"Detected timezone: {timezone}")
confirm_tz = input("Is this timezone correct? (Y/n): ").strip().lower()
if confirm_tz not in ["y", "yes", ""]:
    timezone = input("Enter your preferred timezone (e.g., America/New_York): ").strip()

# Keyboard layout options
clear_screen_with_banner()
keyboard_layouts = {
    "1": "us",
    "2": "uk",
    "3": "de",
    "4": "fr",
    "5": "es"
}
print("Choose keyboard layout:")
for num, layout in keyboard_layouts.items():
    print(f"{num}) {layout}")
keymap_choice = input("Enter the number (1-5) or press Enter to use 'us': ").strip()

# Set the keyboard layout
keymap = keyboard_layouts.get(keymap_choice, "us")

# Ask for the hostname
clear_screen_with_banner()
hostname = input("Enter the hostname: ").strip()

# Ask for the username and password
clear_screen_with_banner()
username = input("Enter the username: ").strip()

# Confirm and validate password (password hidden)
while True:
    clear_screen_with_banner()
    password = getpass.getpass("Enter the password: ")
    confirm_password = getpass.getpass("Confirm the password: ")
    if password == confirm_password:
        break
    else:
        print("Passwords do not match. Please try again.")

# Set the mountpoint for installation
mountpoint = Path('/mnt')

# Begin installation
with Installer(
    mountpoint,
    disk_config,
    kernels=['linux']
) as installation:
    installation.mount_ordered_layout()
    installation.minimal_installation(hostname=hostname)
    installation.add_additional_packages(['nano', 'wget', 'git'])

# Install necessary packages for GRUB inside the chroot environment
clear_screen_with_banner()
print("Installing GRUB and necessary packages...")
subprocess.run(['arch-chroot', str(mountpoint), 'pacman', '-S', '--noconfirm', 'grub', 'efibootmgr', 'os-prober'])

# Install GRUB bootloader
print("Installing GRUB bootloader...")
subprocess.run([
    'arch-chroot', str(mountpoint), 'grub-install', '--target=x86_64-efi',
    '--efi-directory=/boot', '--bootloader-id=GRUB'
])
subprocess.run([
    'arch-chroot', str(mountpoint), 'grub-mkconfig', '-o', '/boot/grub/grub.cfg'
])

# Create the user inside the chroot environment
clear_screen_with_banner()
print("Creating user and adding to the sudoers group...")

# Create the user and add to the 'wheel' group for sudo privileges
subprocess.run(['arch-chroot', str(mountpoint), 'useradd', '-m', '-G', 'wheel', username])

# Set the password for the user
subprocess.run(['arch-chroot', str(mountpoint), 'bash', '-c', f"echo '{username}:{password}' | chpasswd"])

# Ensure the 'wheel' group has sudo privileges in /etc/sudoers
subprocess.run(['arch-chroot', str(mountpoint), 'bash', '-c', "echo '%wheel ALL=(ALL) ALL' >> /etc/sudoers"])

print("User created and added to sudoers.")

# Install NetworkManager and GPU drivers during chroot
clear_screen_with_banner()
print("Installing NetworkManager and GPU drivers...")

subprocess.run(['arch-chroot', str(mountpoint), 'bash', '-c', '''
#!/bin/bash
# Update system
pacman -Syu --noconfirm

# Install NetworkManager and enable it
pacman -S --noconfirm networkmanager 
systemctl enable NetworkManager
systemctl start NetworkManager

# Detect GPU and install appropriate drivers
gpu_type=$(lspci | grep -E "VGA|3D")
if echo "${gpu_type}" | grep -E "NVIDIA|GeForce"; then
    pacman -S --noconfirm --needed nvidia
elif echo "${gpu_type}" | grep 'VGA' | grep -E "Radeon|AMD"; then
    pacman -S --noconfirm --needed xf86-video-amdgpu
elif echo "${gpu_type}" | grep -E "Integrated Graphics Controller"; then
    pacman -S --noconfirm --needed libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils lib32-mesa
elif echo "${gpu_type}" | grep -E "Intel Corporation UHD"; then
    pacman -S --noconfirm --needed libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils lib32-mesa
else
    echo "No supported GPU detected or no drivers required."
fi
'''])

# Final message
clear_screen_with_banner()
print("Arch Linux installation completed successfully.")

# Reboot system
print("Rebooting system...")
subprocess.run(['reboot'])
