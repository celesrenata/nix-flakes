{ config, lib, pkgs, ... }:
let
  selected = import ./features.nix;
  inherit (selected) hostname username;
  feature = selected.features;
in {
  imports = [ ./hardware-configuration.nix ];

  nixpkgs.config.allowUnfree = true;
  networking.hostName = hostname;
  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  networking.networkmanager.enable = true;
  services.pipewire = { enable = true; alsa.enable = true; pulse.enable = true; };
  security.rtkit.enable = true;
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.displayManager.defaultSession = "hyprland";
  programs.hyprland.enable = true;
  programs.git.enable = true;

  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ]
      ++ lib.optionals feature.virtualization [ "libvirtd" "kvm" ]
      ++ lib.optionals feature.ollama [ "video" "render" ];
  };

  environment.systemPackages = with pkgs; [ git vim curl wget foot ]
    ++ lib.optionals feature.development [ gcc cmake gitMinimal nodejs_22 python3 ]
    ++ lib.optionals feature.videoEditing [ ffmpeg-full blender kdenlive ]
    ++ lib.optionals feature.games [ steam gamemode gamescope ]
    ++ lib.optionals feature.virtualization [ virt-manager qemu ]
    ++ lib.optionals feature.ollama [ ollama ];

  programs.steam.enable = feature.games;
  programs.gamemode.enable = feature.games;
  virtualisation.libvirtd.enable = feature.virtualization;
  virtualisation.docker.enable = feature.virtualization;
  services.ollama = lib.mkIf feature.ollama {
    enable = true;
    host = "127.0.0.1";
    port = 11434;
  };

  # Intentionally absent: remote-build, SOPS, vLLM, Arcane, Hyte, and esnixi services.
  system.stateVersion = "26.05";
}
