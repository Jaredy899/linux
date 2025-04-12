# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Enable QEMU Guest Services
  services.qemuGuest.enable = true;

  # Shell initialization
  environment.shellInit = ''
    if [ -f "$HOME/.bashrc" ]; then
      . "$HOME/.bashrc"
    fi
  '';

  # Shell setup configuration
  environment.systemPackages = with pkgs; [
    # Existing packages
    #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    #  wget
    
    # Shell setup packages
    bash
    bash-completion
    gnutar
    bat
    tree
    unzip
    fontconfig
    git
    starship
    fzf
    zoxide
    (nerdfonts.override { fonts = [ "Meslo" ]; })
    fastfetch
    curl

    # Docker related packages
    docker
    docker-compose

    # Neovim and its dependencies
    neovim
    ripgrep
    fzf
    python3
    python3Packages.pynvim
    luaPackages.luarocks
    gcc
    gnumake
    go
    shellcheck
    git
    ninja
    cmake
    unzip
    curl
    tree-sitter
    lazygit
    nodejs    # Added for general Node.js support

    # Editors
    zed-editor
    code-cursor

    # Communication
    signal-desktop
    tailscale
    
    # Terminal
    termius
  ];

  # Allow unfree packages (required for Signal and Zed)
  nixpkgs.config.allowUnfree = true;

  # Automatic system updates
  system.autoUpgrade = {
    enable = true;
    channel = "https://nixos.org/channels/nixos-unstable";
    dates = "03:00"; # Run at 3 AM
    operation = "switch";
    allowReboot = false;
  };

  # Automatic garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users.jared = {
    isNormalUser = true;
    description = "jared";
    extraGroups = [ "networkmanager" "wheel" "docker" "jared" ];
    group = "jared";
    packages = with pkgs; [
    #  thunderbird
        ghostty
        brave
        zed-editor
        neovim
        fastfetch    
    ];
    home = "/home/jared";
    createHome = true;
  };

  # Create the jared group
  users.groups.jared = {};

  # Docker configuration
  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  # Create Docker compose stacks directory
  system.activationScripts.docker-setup = ''
    # Wait for user to be created
    while [ ! -d "/home/jared" ]; do
      sleep 1
    done

    mkdir -p /opt/stacks
    mkdir -p /opt/dockge
    mkdir -p /opt/stacks/portainer

    # Create Dockge compose file
    cat > /opt/dockge/compose.yaml << 'EOF'
---
services:
  dockge:
    image: louislam/dockge:latest
    container_name: dockge
    restart: unless-stopped
    ports:
      - 5001:5001
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./data:/app/data
      - /opt/stacks:/opt/stacks
    environment:
      - DOCKGE_STACKS_DIR=/opt/stacks
EOF

    # Create Portainer compose file
    cat > /opt/stacks/portainer/compose.yaml << 'EOF'
---
services:
  portainer-ce:
    ports:
      - 8000:8000
      - 9443:9443
    container_name: portainer
    restart: always
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    image: portainer/portainer-ce:latest
volumes:
  portainer_data: {}
networks: {}
EOF

    # Set correct permissions
    chown -R 1000:1000 /opt/stacks
    chown -R 1000:1000 /opt/dockge
    chown -R 1000:1000 /opt/stacks/portainer
  '';

  # Shell setup activation script
  system.activationScripts.shell-setup = ''
    # Wait for user to be created
    while [ ! -d "/home/jared" ]; do
      sleep 1
    done

    # Create necessary directories
    mkdir -p /home/jared/.local/share/mybash
    mkdir -p /home/jared/.config/fastfetch
    mkdir -p /home/jared/.config

    # Download configurations from GitHub
    BASE_URL="https://raw.githubusercontent.com/Jaredy899/linux/main/config_changes"
    
    # Download and replace configurations
    ${pkgs.curl}/bin/curl -sSfL -o "/home/jared/.local/share/mybash/.bashrc" "$BASE_URL/.bashrc"
    ${pkgs.curl}/bin/curl -sSfL -o "/home/jared/.config/fastfetch/config.jsonc" "$BASE_URL/config.jsonc"
    ${pkgs.curl}/bin/curl -sSfL -o "/home/jared/.config/starship.toml" "$BASE_URL/starship.toml"

    # Create symbolic links
    ln -sf /home/jared/.local/share/mybash/.bashrc /home/jared/.bashrc

    # Add fastfetch to .bashrc if not already present
    if ! grep -q "fastfetch" /home/jared/.bashrc; then
      echo -e "\n# Run fastfetch on shell initialization\nfastfetch" >> /home/jared/.bashrc
    fi

    # Set correct permissions
    chown -R 1000:1000 /home/jared/.local
    chown -R 1000:1000 /home/jared/.config
    chown 1000:1000 /home/jared/.bashrc
  '';

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # SSH configuration
  # programs.ssh = {
  #   askPassword = pkgs.lib.mkForce "${pkgs.ksshaskpass}/bin/ksshaskpass";  # Use KDE's SSH askpass
  # };

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/New_York";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;
    
  # Enable KDE Plasma
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Enable XFCE
  # services.xserver.desktopManager.xfce.enable = true;

  # Enable GNOME
  # services.xserver.desktopManager.gnome.enable = true;

  # Set default applications
  xdg.portal.enable = true;
  xdg.mime.defaultApplications = {
    "x-scheme-handler/http" = "brave-browser.desktop";
    "x-scheme-handler/https" = "brave-browser.desktop";
    "text/html" = "brave-browser.desktop";
    "x-scheme-handler/terminal" = "com.mitchellh.ghostty.desktop";
  };

  # Configure KDE Plasma
  environment.sessionVariables = {
    TERMINAL = "ghostty";
    BROWSER = "brave";
  };

  # Install firefox.
  programs.firefox.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
   programs.mtr.enable = true;
   programs.gnupg.agent = {
     enable = true;
     enableSSHSupport = true;
     # pinentryPackage = pkgs.lib.mkForce pkgs.pinentry-qt; # Force using Qt pinentry for consistency
   };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
   services.openssh.enable = true;

  # Enable Tailscale
  services.tailscale.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
