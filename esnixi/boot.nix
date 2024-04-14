let
  # RTX 3070 Ti
  gpuIDs = [
    "10de:2786" # Graphics
    "10de:22bc" # Audio
  ];
in 
{ config, lib, pkgs, ... }:
{
  options.vfio.enable = with lib;
    mkEnableOption "Configure the machine for VFIO";

  config = let cfg = config.vfio;
  in {
    boot = {
      loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
      };
      supportedFilesystems = [ "ntfs" "nfs" ];
      plymouth.enable = true;
      kernelPackages = pkgs.linuxPackages_latest;
      kernelModules = [ "uinput" "nvidia" ];
      extraModprobeConfig = ''
        options nvidia NVreg_OpenRmEnableUnsupportedGpus=1
        options nvidia NVreg_EnablePCIeGen3=1
        options nvidia NVreg_EnableGpuFirmware=0
      '';
      initrd.kernelModules = [
        "vfio_pci"
        "vfio"
        "vfio_iommu_type1"

        "nvidia"
        "nvidia_modeset"
        "nvidia_uvm"
        "nvidia_drm"
      ];

      kernelParams = [
        # enable IOMMU
        "amd_iommu=on"
      ] ++ lib.optional cfg.enable
        # isolate the GPU
        ("vfio-pci.ids=" + lib.concatStringsSep "," gpuIDs);
    };
    hardware.opengl.enable = true;
    virtualisation.spiceUSBRedirection.enable = true;
  };
}
