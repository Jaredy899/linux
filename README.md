# Jared's Linux Installs

A collection of shell scripts for automated Linux setup and configuration. This toolkit helps you quickly set up a new Linux system with essential utilities and configurations.

## 🚀 Features

- **Post-install Setup**: Install standard utilities and configure basic system settings
- **Linux Utility**: Run Chris Titus Tech's Linutil for additional system optimizations
- **SSH Key Management**: Easily add and configure SSH keys
- **Network Drive Setup**: Mount and configure network storage
- **Tailscale VPN**: Install and configure Tailscale for secure networking
- **Docker Installation**: Set up Docker and Docker Compose
- **Config Replacement**: Replace default configs with optimized versions
- **System Updates**: Keep your system up to date

## 💡 Usage

### Quick Start

To get started, open your terminal and run the following command:

```sh
sh <(curl -fsSL jaredcervantes.com/linux)
```

### Arch Linux Installation

This toolkit includes special support for Arch Linux installation. When run from an Arch Linux ISO environment, it will automatically detect this and offer to run the Arch installation script.

## 🛠️ Available Options

The main menu provides the following options:

1. **Run Post Install Script** - Install and configure essential utilities
2. **Run Linux Utility** - Launch the Jared Linux Utility for system tweaks
3. **Add SSH Key** - Configure SSH key authentication
4. **Install a Network Drive** - Set up network storage mounts
5. **Install Tailscale** - Set up Tailscale VPN for secure networking
6. **Install Docker** - Install Docker and related tools
7. **Replace Configs** - Replace configuration files with optimized versions
8. **Update System** - Run system updates
9. **Exit** - Exit the script

## 🔧 Advanced Usage

### Manual Installation

You can also clone this repository and run the scripts directly:

```sh
git clone https://github.com/Jaredy899/linux.git
cd linux
chmod +x linux.sh
./linux.sh
```

### Custom Scripts

Each functionality is implemented as a separate script in the `installs` directory, which can be run individually if needed.

## 📝 License

This project is open source and available under the [MIT License](LICENSE).

## 🤝 Contributing

Contributions are welcome! Feel free to submit issues or pull requests.

## 📚 Documentation

For more detailed information about each component, see the comments in the individual script files.

