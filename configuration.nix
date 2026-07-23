# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, pkgsAccel, inputs, ... }:
{
  # Licences.
  # nixpkgs.config.allowUnfree = true;  # Already set in flake pkgs
  nixpkgs.hostPlatform = "x86_64-linux";

  imports =
    [ # Include the results of the hardware scan.
      #"${pkgs}/nixos/modules/programs/alvr.nix"
      # Hardware-configuration.nix is imported per-host in flake.nix
      inputs.dots-hyprland.nixosModules.default  # UPower and other system services
      # ./logi-dictation-filter.nix  # Disabled: can't grab keyd output without losing keyboard
    ];

  environment.localBinInPath = true;

  # Enable nix-ld for dynamically linked binaries (kiro-cli bun, etc.)
  programs.nix-ld.enable = true;
  # Enable Flakes.
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    download-buffer-size = 8589934592; # 8gb
    cores = 20;
    max-jobs = 4;
  };
  
  systemd.services.set-github-token = {
    description = "Set GitHub Token for Nix";
    after = [ "network.target" ];
    before = [ "nix-daemon.service" ];
    serviceConfig.ExecStart = ''
      /bin/sh -c 'echo "access-tokens = github.com=$(cat ${config.sops.secrets.github_token.path})" > /etc/nix/access-tokens'
    '';
    wantedBy = [ "multi-user.target" ];
  };
  
  systemd.services.nix-daemon.after = [ "set-github-token.service" ];
  
  # Bootloader.
  # boot.loader.systemd-boot.enable = true;
  # boot.loader.efi.canTouchEfiVariables = true;
  #boot.kernelPackages = lib.mkForce pkgs.linuxPackages_6_6;
  boot.plymouth.enable = true;
  # Use the Grub EFI boot loader.

  # Certificate management via sops-nix
  # Temporarily disabled during initial build to avoid chicken-and-egg problem
  # security.pki.certificateFiles = [
  #   "/run/secrets/home.crt"
  # ];
  security.pam.loginLimits = [
    {domain = "*"; item = "stack"; type = "-"; value = "unlimited";}
  ];
  # Udev rules.
  # hardware.uinput.enable = true;
  services.gvfs.enable = true;
  # Set your time zone.

  #services.automatic-timezoned.enable = true;
  #location.provider = "geoclue2";
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

  # Enable the GDM Display Manager.
  services.displayManager.gdm = {
    enable = true;
    autoSuspend = false;
  };
  services.xserver.displayManager = {
    #setupCommands = "export WLR_BACKENDS=headless";
    #autoLogin.enable = true;
    #autoLogin.user = "celes";
  };

  services.displayManager.defaultSession = "hyprland";
  
  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the Enlightenment Desktop Environment.
  #services.xserver.desktopManager.enlightenment.enable = true;

  # Enable OpenRGB.
  services.hardware.openrgb.enable = true;

  programs.hyprland = {
    # Install the packages from nixpkgs
    enable = true;
    package = pkgs.hyprland;
    portalPackage = pkgs.xdg-desktop-portal-hyprland;
    xwayland.enable = true;
  };

#  services.monado = {
#    enable = true;
#    defaultRuntime = true; # Register as default OpenXR runtime
#  };
#
#  systemd.user.services.monado.environment = {
#    STEAMVR_LH_ENABLE = "1";
#    XRT_COMPOSITOR_COMPUTE = "1";
#    WMR_HANDTRACKING = "0";
#  };

  #programs.niri = {
  #  enable = true;
  #  package = niri.packages.x86_64-linux.niri-unstable;
  #};

  programs.fish = {
    enable = true;
  };

  # Enable Location.
  services.geoclue2.enable = true;

  # Enable acpid
  services.acpid.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;
  services.printing.drivers = [ pkgs.gutenprint ];
  hardware.sane.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  services.fwupd.enable = true;

  # Enable sound with pipewire.
  #sound.enable = true;
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  services.jack = {
    #jackd.enable = true;
    # support ALSA only programs via ALSA JACK PCM plugin
    alsa.enable = true;
    # support ALSA only programs via loopback device (supports programs like Steam)
    loopback = {
      enable = true;
      # buffering parameters for dmix device to work with ALSA only semi-professional sound programs
      #dmixConfig = ''
      #  period_size 2048
      #'';
    };
  };

  # Enable Fonts.
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    dejavu_fonts
    _0xproto
    liberation_ttf
    fira-code
    fira-code-symbols
    mplus-outline-fonts.githubRelease
    dina-font
    proggyfonts
    fontconfig
    lexend
    nerd-fonts.dejavu-sans-mono
    nerd-fonts.space-mono
    material-symbols
    bibata-cursors
  ];

  programs.git = {
    enable = true;
    lfs.enable = true;
  };

  # Extra Groups
  users.groups.mlocate = {};
  users.groups.plocate = {};
  users.groups.libvirt = {};
  users.groups.kvm = {};


  security.sudo.configFile = ''
    root   ALL=(ALL:ALL) SETENV: ALL
    %wheel ALL=(ALL:ALL) SETENV: ALL
    celes  ALL=(ALL:ALL) SETENV: ALL
  '';

  # Gnome Keyring
  services.gnome.gnome-keyring.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;

  # keyd: kernel-level key remapping (replaces Toshy)
  # Mac-style Ctrl↔Super swap + dictation triggers
  services.keyd = {
    enable = true;
    keyboards.mac = {
      ids = [ "*" ];
      settings = {
        main = {
          # Mac-style: left ctrl becomes super, super becomes ctrl
          control = "layer(meta)";
          meta = "layer(control)";
          # Left Alt: tap = dispatch dictation via hyprctl, hold = alt
          leftalt = "overload(alt, command(/etc/keyd/dictation-dispatch.sh))";
          # Logi Dictation button — dispatch directly (bypasses layer processing)
          micmute = "command(/etc/keyd/dictation-dispatch.sh)";
        };
        # Override micmute in control layer too (Logi sends it while Meta is held)
        "control:C" = {
          micmute = "command(/etc/keyd/dictation-dispatch.sh)";
          # Logi dictation button sends Meta+H → enters control layer → intercept H
          h = "command(/etc/keyd/dictation-dispatch.sh)";
        };
        "meta:M" = {
          micmute = "command(/etc/keyd/dictation-dispatch.sh)";
        };
      };
    };
  };

  # Keyd dictation dispatch wrapper script
  # Runs as root from keyd - resolves Hyprland socket and dispatches with logging
  environment.etc."keyd/dictation-dispatch.sh" = {
    mode = "0755";
    text = ''
      #!/usr/bin/env bash
      LOG_TAG="keyd-dictation"
      TIMESTAMP=$(date +%s.%N)
      HYPR_SIG=$(find /run/user/*/hypr -maxdepth 1 -name ".socket.sock" 2>/dev/null | head -1 | xargs dirname | xargs basename)
      RUNTIME_DIR=$(find /run/user -maxdepth 1 -type d -name "[0-9]*" 2>/dev/null | head -1)
      if [ -z "$HYPR_SIG" ] || [ -z "$RUNTIME_DIR" ]; then
        logger -t "$LOG_TAG" "FAIL ts=$TIMESTAMP reason=no_hyprland_socket"
        exit 1
      fi
      export HYPRLAND_INSTANCE_SIGNATURE="$HYPR_SIG"
      export XDG_RUNTIME_DIR="$RUNTIME_DIR"
      logger -t "$LOG_TAG" "DISPATCH ts=$TIMESTAMP sig=$HYPR_SIG"
      RESULT=$("${pkgs.hyprland}/bin/hyprctl" dispatch global quickshell:dictationTap 2>&1)
      EXIT_CODE=$?
      if [ $EXIT_CODE -eq 0 ]; then
        logger -t "$LOG_TAG" "OK ts=$TIMESTAMP result=$RESULT"
      else
        logger -t "$LOG_TAG" "FAIL ts=$TIMESTAMP exit=$EXIT_CODE result=$RESULT"
      fi
    '';
  };

  # Gestures with custom configuration
  services.touchegg.enable = true;
  
  # System-wide touchegg configuration file
  environment.etc."touchegg/touchegg.conf".text = ''
    <touchégg>
      <settings>
        <property name="animation_delay">150</property>
        <property name="action_execute_threshold">80</property>
        <property name="color">auto</property>
        <property name="borderColor">auto</property>
      </settings>
      <application name="All">
        <!-- 3-finger pinch in: Close window -->
        <gesture type="PINCH" fingers="3" direction="IN">
          <action type="CLOSE_WINDOW">
            <animate>true</animate>
            <color>F84A53</color>
            <borderColor>F84A53</borderColor>
          </action>
        </gesture>
        
        <!-- 2-finger tap: Right click -->
        <gesture type="TAP" fingers="2" direction="UNKNOWN">
          <action type="MOUSE_CLICK">
            <button>3</button>
            <on>begin</on>
          </action>
        </gesture>
        
        <!-- 3-finger click: Middle click (Hyprland handles the dragging) -->
        <gesture type="CLICK" fingers="3" direction="UNKNOWN">
          <action type="MOUSE_CLICK">
            <button>2</button>
            <on>begin</on>
          </action>
        </gesture>
        
        <!-- 4-finger pinch in: Fullscreen mode 0 -->
        <gesture type="PINCH" fingers="4" direction="IN">
          <action type="RUN_COMMAND">
            <command>hyprctl dispatch fullscreen 0</command>
            <repeat>false</repeat>
            <animation>NONE</animation>
            <on>begin</on>
          </action>
        </gesture>
        
        <!-- 4-finger pinch out: Fullscreen mode 1 -->
        <gesture type="PINCH" fingers="4" direction="OUT">
          <action type="RUN_COMMAND">
            <command>hyprctl dispatch fullscreen 1</command>
            <repeat>false</repeat>
            <animation>NONE</animation>
            <on>begin</on>
          </action>
        </gesture>
        
        <!-- 3-finger swipe up: Show overview -->
        <gesture type="SWIPE" fingers="3" direction="UP">
          <action type="RUN_COMMAND">
            <command>hyprctl dispatch global quickshell:overviewToggle</command>
            <repeat>false</repeat>
            <animation>NONE</animation>
            <on>begin</on>
          </action>
        </gesture>
        
        <!-- 3-finger swipe down: Show all windows -->
        <gesture type="SWIPE" fingers="3" direction="DOWN">
          <action type="RUN_COMMAND">
            <command>hyprctl dispatch overview</command>
            <repeat>false</repeat>
            <animation>NONE</animation>
            <on>begin</on>
          </action>
        </gesture>
        
        <!-- 4-finger swipe left: Open right sidebar -->
        <gesture type="SWIPE" fingers="4" direction="LEFT">
          <action type="RUN_COMMAND">
            <command>/home/celes/.local/bin/gesture-toggle.sh left</command>
            <repeat>false</repeat>
            <animation>NONE</animation>
            <on>begin</on>
          </action>
        </gesture>
        
        <!-- 4-finger swipe right: Open left sidebar -->
        <gesture type="SWIPE" fingers="4" direction="RIGHT">
          <action type="RUN_COMMAND">
            <command>/home/celes/.local/bin/gesture-toggle.sh right</command>
            <repeat>false</repeat>
            <animation>NONE</animation>
            <on>begin</on>
          </action>
        </gesture>
        
        <!-- 4-finger swipe up: Kando / close overview -->
        <gesture type="SWIPE" fingers="4" direction="UP">
          <action type="RUN_COMMAND">
            <command>/home/celes/.local/bin/gesture-toggle.sh up</command>
            <repeat>false</repeat>
            <animation>NONE</animation>
            <on>begin</on>
          </action>
        </gesture>
        
        <!-- 4-finger swipe down: Overview / close kando -->
        <gesture type="SWIPE" fingers="4" direction="DOWN">
          <action type="RUN_COMMAND">
            <command>/home/celes/.local/bin/gesture-toggle.sh down</command>
            <repeat>false</repeat>
            <animation>NONE</animation>
            <on>begin</on>
          </action>
        </gesture>
      </application>
      
    </touchégg>
  '';

  # Garbage Collection.
  nix.optimise.automatic = true;
  
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.celes = {
    isNormalUser = true;
    description = "Celes Renata";
    extraGroups = [ "networkmanager" "scanner" "lp" "wheel" "input" "uinput" "render" "video" "audio" "docker" "libvirt" "kvm" "vboxusers" "adbusers" "gamemode" ];
    packages = with pkgs; [
      firefox-bin
    #  thunderbird
    ];
  };

  # Shell aliases for OneTrainer
  environment.shellAliases = {
    onetrainer = "nix run github:celesrenata/OneTrainer-flake";
    onetrainer-ui = "nix run github:celesrenata/OneTrainer-flake#onetrainer-ui";
    onetrainer-cli = "nix run github:celesrenata/OneTrainer-flake#onetrainer-cli";
    onetrainer-convert = "nix run github:celesrenata/OneTrainer-flake#onetrainer-convert";
  };

  # List packages installed in system profile. To search, run:
  # Enable Wayland for Electron.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  environment.sessionVariables.MOZ_ENABLE_WAYLAND = "1";

  # $ nix search wget
  environment.systemPackages = with pkgs; [
    bibata-cursors
    # Editors.
    vim
    
    # CLI Tools
    inputs.cline-cli.packages.x86_64-linux.default
    inputs.kiro-cli.packages.x86_64-linux.default
    
    # Secrets Management
    sops
    
    # Networking Tools.
    wget
    curl
    rsync
    nmap
    pssh
    tmate

    # Audio.
    ladspaPlugins
    calf
    lsp-plugins
    easyeffects
    alsa-utils

    # System Tools.
    mesa-demos
    blueman
    networkmanagerapplet
    kdePackages.kcmutils  # Provides kcmshell6 for quickshell
    kdePackages.kde-cli-tools  # KDE CLI tools for quickshell
    kdePackages.plasma-nm  # KDE network manager for quickshell
    kdePackages.bluedevil  # KDE bluetooth manager for quickshell
    kdePackages.bluez-qt  # Bluetooth QML module
    kdePackages.plasma-workspace  # Plasma private modules
    nix-index
    mlocate
    util-linux
    openssl
    xsane
    simple-scan
    screen
    freerdp
    mako
    keymapp
    android-tools
    postgresql
    gvfs

    # Shells.
    fish
    zsh
    bash

    # Development Tools (not in profiles).
    uv
    amazon-q-cli
    kiro
    jetbrains-toolbox

    # Session.
    polkit
    polkit_gnome
    dconf
    killall
    gnome-keyring
    wayvnc
    evtest
    zenity
    linux-pam
    cliphist
    sudo
    #xwaylandvideobridge
    ssh-tools

    # Wayland.
    xdg-desktop-portal-hyprland
    xwayland
    brightnessctl
    ydotool
    awww
    hyprpaper
    fcitx5
    wlsunset
    wtype
    wl-clipboard
    xhost
    wev
    wf-recorder
    vulkan-tools
    libva-utils
    wofi
    libqalculate
    #sunshine 
    moonlight-qt
    thunar
    thunar-volman
    wayland-scanner
    waypipe

    # Media
    plex-desktop
    jellyfin-media-player
    
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

    # Latex
    texliveFull
    texlive.combined.scheme-full
    latexRes-package

    # Terminals.
    kitty
    foot

    # Emulation
    wine
    wine64
    qemu

    # Mac Sound.
    libspatialaudio
    pulseaudio
    #t2AppleAudioDSP

    # Mac Camera.
    libcamera
  ];

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings = {
      X11Forwarding = true;
      X11DisplayOffset = 10;
      X11UseLocalhost = true;
    };
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "26.05"; # Did you read the comment?
}
