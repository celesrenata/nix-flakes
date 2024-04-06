{ ... }:
{
  config = {
    # Bootloader.
    boot = {
      loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
      };
      supportedFilesystems = [ "ntfs" "nfs" ];
      plymouth.enable = true;
      kernelModules = [ "uinput" "nvidia" ];
      extraModprobeConfig = ''
        options nvidia NVreg_OpenRmEnableUnsupportedGpus=1
        options nvidia NVreg_EnablePCIeGen3=1
        options nvidia NVreg_EnableGpuFirmware=0
      '';
    };
  };
}
