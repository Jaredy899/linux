from pathlib import Path
from archinstall import Installer, profile, disk, models
from archinstall.default_profiles.minimal import MinimalProfile
import subprocess
import os
import getpass
import urllib.request
import json

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

# Function to get timezone and country information
def get_timezone_and_country():
    try:
        response = urllib.request.urlopen("https://ipapi.co/json")
        data = json.load(response)
        return {
            "timezone": data["timezone"],
            "country_code": data["country_code"]
        }
    except Exception as e:
        print(f"Failed to detect timezone and country: {e}")
        return {
            "timezone": "UTC",
            "country_code": "US"  # Default to "US" if detection fails
        }

# Function to allow the user to select the disk by number
def select_disk():
    clear_screen_with_banner()
    print("Available disks:")
    
    # List all available disks using lsblk and extract the device names and sizes
    result = subprocess.run(['lsblk', '-dn', '-o', 'NAME,SIZE,TYPE', '--json'], capture_output=True, text=True)
    devices = json.loads(result.stdout)["blockdevices"]

    # Filter out non-disk devices
    disks = [dev for dev in devices if dev["type"] == "disk"]
    
    # Display disks with numbers
    for index, disk in enumerate(disks):
        print(f"{index + 1}) {disk['name']} - {disk['size']}")

    # Prompt the user to select a disk
    while True:
        disk_choice = input(f"Select a disk by number (1-{len(disks)}): ").strip()
        if disk_choice.isdigit() and 1 <= int(disk_choice) <= len(disks):
            selected_disk = disks[int(disk_choice) - 1]["name"]
            break
        else:
            print("Invalid choice. Please enter a valid number.")

    disk_path = f"/dev/{selected_disk}"
    print(f"Selected disk: {disk_path}")
    return disk_path

# # Function to set up the mirrors using reflector
# def setup_mirrors():
#     print("Setting up mirrors for optimal download")
    
#     # Get country ISO code based on public IP
#     try:
#         iso = subprocess.check_output("curl -4 ifconfig.co/country-iso", shell=True).decode().strip()
#         print(f"Detected country ISO: {iso}")
#     except subprocess.CalledProcessError as e:
#         print(f"Error detecting country ISO: {e}")
#         iso = "US"  # Fallback to US if detection fails

#     # Sync system time
#     subprocess.run(['timedatectl', 'set-ntp', 'true'])

#     # Update keyrings and install necessary packages
#     subprocess.run(['pacman', '-S', '--noconfirm', 'archlinux-keyring'])

#     # Enable parallel downloads
#     subprocess.run(["sed", "-i", "'s/^#ParallelDownloads/ParallelDownloads/'", "/etc/pacman.conf"])

#     # Install reflector and other packages
#     subprocess.run(['pacman', '-S', '--noconfirm', '--needed', 'reflector', 'rsync', 'grub'])

#     # Backup mirrorlist
#     subprocess.run(['cp', '/etc/pacman.d/mirrorlist', '/etc/pacman.d/mirrorlist.backup'])

#     print(f"\nSetting up {iso} mirrors for faster downloads...\n")

#     # Use reflector to update the mirrorlist with the best mirrors based on country ISO
#     subprocess.run([
#         'reflector', '-a', '48', '-c', iso, '-f', '5', '-l', '20', '--sort', 'rate', '--save', '/etc/pacman.d/mirrorlist'
#     ])

#     if not os.path.exists('/mnt'):
#         os.makedirs('/mnt')

# # Call mirror setup before installation
# setup_mirrors()

# Select disk for installation
disk_path = select_disk()

# Ask the user for the desired filesystem
clear_screen_with_banner()
print("Choose filesystem:")
print("1) Btrfs")
print("2) ext4")
print("3) XFS")
fs_choice = input("Enter the number (1, 2, or 3): ").strip()

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
device = disk.device_handler.get_device(Path(disk_path))
if not device:
    raise ValueError(f"No device found for path {disk_path}")

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

# Get the timezone and country automatically
clear_screen_with_banner()
location_info = get_timezone_and_country()
timezone = location_info["timezone"]
country_code = location_info["country_code"]

print(f"Detected timezone: {timezone}")
confirm_tz = input("Is this timezone correct? (Y/n): ").strip().lower()
if confirm_tz not in ["y", "yes", ""]:
    timezone = input("Enter your preferred timezone (e.g., America/New_York): ").strip()

# Set the timezone in the mounted system
try:
    timezone_path = Path('/mnt/etc/localtime')
    timezone_symlink = f"/usr/share/zoneinfo/{timezone}"
    subprocess.run(['ln', '-sf', timezone_symlink, str(timezone_path)], check=True)
    print(f"Timezone set to {timezone}.")
except Exception as e:
    print(f"Failed to set timezone: {e}")

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

# Configure the keymap in the mounted system
try:
    keymap_path = Path('/mnt/etc/vconsole.conf')
    with open(keymap_path, "w") as kbd_file:
        kbd_file.write(f"KEYMAP={keymap}\n")
    print(f"Keyboard layout set to {keymap}.")
except Exception as e:
    print(f"Failed to set keyboard layout: {e}")

# Ask for the hostname
clear_screen_with_banner()
hostname = input("Enter the hostname: ").strip()

# Configure the hostname in the mounted system
try:
    hostname_path = Path('/mnt/etc/hostname')
    with open(hostname_path, "w") as host_file:
        host_file.write(f"{hostname}\n")
    print(f"Hostname set to {hostname}.")
except Exception as e:
    print(f"Failed to set hostname: {e}")

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

# Set the timezone and synchronize the system clock in the chroot environment
clear_screen_with_banner()
print(f"Setting the timezone to {timezone} and syncing system time...")

try:
    # Set the timezone inside the chroot environment
    subprocess.run(['arch-chroot', str(mountpoint), 'ln', '-sf', f'/usr/share/zoneinfo/{timezone}', '/etc/localtime'], check=True)

    # Sync hardware clock inside the chroot environment
    subprocess.run(['arch-chroot', str(mountpoint), 'hwclock', '--systohc'], check=True)

    # Enable network time synchronization
    subprocess.run(['arch-chroot', str(mountpoint), 'timedatectl', 'set-ntp', 'true'], check=True)

    print("Timezone and system clock have been set successfully.")
except subprocess.CalledProcessError as e:
    print(f"Error setting timezone or syncing clock: {e}")

# Install GRUB bootloader on the selected disk
print("Installing GRUB bootloader...")
subprocess.run([
    'arch-chroot', str(mountpoint), 'grub-install', '--target=x86_64-efi',
    '--efi-directory=/boot', '--bootloader-id=GRUB', '--recheck', disk_path
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

# Install NetworkManager, GPU drivers, and Terminus font in chroot
clear_screen_with_banner()
print("Installing NetworkManager, GPU drivers, and setting Terminus font...")

subprocess.run(['arch-chroot', str(mountpoint), 'bash', '-c', '''
#!/bin/bash
# Update system
pacman -Syu --noconfirm

# Install NetworkManager and enable it
pacman -S --noconfirm networkmanager nm-connection-editor
systemctl enable --now NetworkManager
systemctl enable --now sshd


# Detect GPU and install appropriate drivers
gpu_type=$(lspci | grep -E "VGA|3D")
if echo "${gpu_type}" | grep -E "NVIDIA|GeForce"; then
    pacman -S --noconfirm --needed nvidia nvidia-settings
elif echo "${gpu_type}" | grep 'VGA' | grep -E "Radeon|AMD"; then
    pacman -S --noconfirm --needed xf86-video-amdgpu
elif echo "${gpu_type}" | grep -E "Integrated Graphics Controller"; then
    pacman -S --noconfirm --needed libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-utils lib32-mesa
elif echo "${gpu_type}" | grep -E "Intel Corporation UHD"; then
    pacman -S --noconfirm --needed libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-utils lib32-mesa
else
    echo "No supported GPU detected or no drivers required."
fi

# Install Terminus font and set it permanently
pacman -S --noconfirm --needed pacman-contrib terminus-font
setfont ter-v18b
echo "FONT=ter-v18b" >> /etc/vconsole.conf
'''])

# Final message
clear_screen_with_banner()
print("Arch Linux installation completed successfully.")

# Reboot system
print("Rebooting system...")
subprocess.run(['reboot'])
