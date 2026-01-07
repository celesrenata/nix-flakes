{ config, lib, pkgs, pkgs-unstable, ... }:
let
  myKernelPackages = let
    base = pkgs.linuxKernel.packages.linux_6_18;
  in base // {
    nvidia-open = base.nvidia-open.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.pkg-config ];
      buildInputs = (old.buildInputs or []) ++ [ pkgs.gtk3 pkgs.gtk2 ];
    });
    xpadneo = pkgs.linuxKernel.packages.linux_6_18.xpadneo.overrideAttrs(old: {
      patches = (old.patches or []) ++ [
        (pkgs.fetchpatch {
          url = "https://github.com/orderedstereographic/xpadneo/commit/233e1768fff838b70b9e942c4a5eee60e57c54d4.patch";
          hash = "sha256-HL+SdL9kv3gBOdtsSyh49fwYgMCTyNkrFrT+Ig0ns7E=";
          stripLen = 2;
        })
      ];
    });
  };
in
{
  config = {
    nixpkgs.config.allowUnsupportedSystem = true;
    boot = {
      binfmt.emulatedSystems = [ "aarch64-linux" ];
      loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
      };
      supportedFilesystems = [ "ntfs" "nfs" ];
      plymouth.enable = true;

      # Use patched kernelPackages set
      kernelPackages = myKernelPackages;

      kernelPatches = [
        {
          name = "amdgpu-ignore-ctx-privileges";
          patch = pkgs.fetchpatch {
            name = "cap_sys_nice_begone.patch";
            url = "https://github.com/Frogging-Family/community-patches/raw/master/linux61-tkg/cap_sys_nice_begone.mypatch";
            hash = "sha256-Y3a0+x2xvHsfLax/uwycdJf3xLxvVfkfDVqjkxNaYEo=";
          };
        }
      ];
      kernelModules = [ "uinput" "nvidia" "v4l2loopback" ];

      # Disable DP-3 at boot to prevent GDM from claiming it
      kernelParams = [ ];

      # Use whatever v4l2loopback package you want, or comment if handled via kernelPackages
      extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback xpadneo ];

      extraModprobeConfig = ''
        options nvidia_drm modeset=1 fbdev=1
      '';

      # initrd kernel modules
      initrd.kernelModules = [
        "nvidia"
        "nvidia_modeset"
        "nvidia_uvm"
        "nvidia_drm"
      ];
    };
    hardware.graphics.enable = true;
    services.thermald.enable = true;
    # virtualisation.spiceUSBRedirection.enable = true;
  };
}

