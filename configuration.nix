# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:
{
  # Licences.
  nixpkgs.config.allowUnfree = true;

  # Inscure packages allowed.
  nixpkgs.config.permittedInsecurePackages = [
    "python-2.7.18.7"
  ];

  # Overlays.
  nixpkgs.overlays = [
    (import ./overlays/python-xlib/python-xlib.nix)
    (import ./overlays/python-keyszer/python-keyszer.nix)
  ];

  imports =
    [ # Include the results of the hardware scan.ot
      #"${builtins.fetchGit { url = "https://github.com/NixOS/nixos-hardware.git";}}/apple/t2"
      ./hardware-configuration.nix
    ];

  # File Systems.
  fileSystems."/" = {
    device = "/dev/nvme0n1p3";
    fsType = "ext4";
  };
  fileSystems."/boot/EFI" = {
    device = "/dev/nvme0n1p4";
    fsType = "vfat";
  };
  # Enable Flakes.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Enable GPUs.
  /*
  systemd.tmpfiles.rules = [
    "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}"
  ];
  hardware.opengl.driSupport = true; # This is already enabled by default
  hardware.opengl.driSupport32Bit = true; # For 32 bit applications
  hardware.opengl.extraPackages = with pkgs; [
    amdvlk
    rocmPackages.clr.icd
  ];
  # For 32 bit applications 
  hardware.opengl.extraPackages32 = with pkgs; [
    driversi686Linux.amdvlk
  ];
  */
  # Bootloader.
  boot.initrd.kernelModules = [ "amdgpu" ];
  boot.kernelModules = [ "uinput" ];
  # for Southern Islands (SI i.e. GCN 1) cards
  #boot.kernelParams = [ "radeon.si_support=0" "amdgpu.si_support=1" ];
  # for Sea Islands (CIK i.e. GCN 2) cards
  #boot.kernelParams = [ "radeon.cik_support=0" "amdgpu.cik_support=1" ];

   # Use the Grub EFI boot loader.
   boot.loader = {
     efi = {
       efiSysMountPoint = "/boot/EFI";
     };

     grub = {
       efiSupport = true;
       efiInstallAsRemovable = true;
       device = "nodev";
     };
   };
 
  # Udev rules.
  hardware.uinput.enable = true;

  # Networking.
  networking.hostName = "macland"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable NetworkManager.
  networking.networkmanager.enable = true;

  # Enable Bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  # Set your time zone.
  time.timeZone = "America/Los_Angeles";

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

  # Enable the Sddm Display Manager
  services.xserver.displayManager.sddm.enable = true;

  # Enable the X11 windowing system.
  services.xserver.enable = true;
  services.xserver.videoDrivers = [ "amdgpu" ];

  # Enable the Enlightenment Desktop Environment.
  services.xserver.desktopManager.enlightenment.enable = true;

  programs.hyprland = {
    # Install the packages from nixpkgs
    enable = true;
    # Whether to enable Xwayland
    xwayland.enable = true;
  };

  # Enable acpid
  services.acpid.enable = true;

  # Configure keymap in X11
  services.xserver = {
    layout = "us";
    xkbVariant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };
 
  # Enable fonts.
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk
    noto-fonts-emoji
    liberation_ttf
    fira-code
    fira-code-symbols
    mplus-outline-fonts.githubRelease
    dina-font
    proggyfonts
  ];

  # Extra Groups
  users.groups.mlocate = {};
  users.groups.plocate = {};

  security.sudo.configFile = ''
    root   ALL=(ALL:ALL) SETENV: ALL
    %wheel ALL=(ALL:ALL) SETENV: ALL
    celes  ALL=(ALL:ALL) SETENV: ALL
  '';

  # Gnome Keyring
  services.gnome.gnome-keyring.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  services.xserver.libinput.enable = true;
  services.touchegg.enable = true;


  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.celes = {
    isNormalUser = true;
    description = "Celes Renata";
    extraGroups = [ "networkmanager" "wheel" "input" "uinput" "render" "video" "audio" ];
    packages = with pkgs; [
      firefox
    #  thunderbird
    ];
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # Editors.
    vim
    
    # Networking Tools.
    wget
    curl
    rsync
    nmap

    # System Tools.
    btop
    nvtop
    blueman
    networkmanagerapplet
    nix-index
    mlocate

    # Other Stuff.
    sqlite

    # Shells.
    fish
    zsh
    bash

    # Development Tools.
    git
    nodejs_21
    meson
    gcc13
    cmake
    pkg-config
    glib.dev
    glib
    glibc.dev
    gobject-introspection.dev
    pango.dev
    harfbuzz.dev
    cairo.dev
    gdk-pixbuf.dev
    atk.dev
    libpulseaudio.dev
    typescript
    ninja
    nixStatic.dev
    node2nix
    nil

    # Session.
    polkit
    polkit_gnome
    dconf
    killall
    gnome.gnome-keyring
    wayvnc
    evtest
    gnome.zenity
    linux-pam
    cliphist
    sudo

    # Wayland.
    xdg-desktop-portal-hyprland
    xwayland
    brightnessctl
    ydotool
    swww
    fcitx5
    wlsunset
    wtype
    wl-clipboard
    xorg.xhost
    blender-hip

    # GTK
    gtk3
    gtk3.dev
    libappindicator-gtk3.dev
    libnotify.dev
    gtk4
    gtk4.dev
    gjs
    gjs.dev
    gtksourceview
    gtksourceview.dev
    xdg-desktop-portal-gtk

    # Not GTK.
    tk

    # Terminals.
    kitty
    foot
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Enable VMWare Tools.
  virtualisation.vmware.guest.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
  # home-manager.users.celes = import ./home.nix;
}
