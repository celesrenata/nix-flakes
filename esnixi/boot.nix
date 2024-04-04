{ ... }:
{
  config = {
    # Bootloader.
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.plymouth.enable = true;
    boot.kernelModules = [ "uinput" "nvidia" ];
    boot.extraModprobeConfig = ''
      options nvidia NVreg_OpenRmEnableUnsupportedGpus=1
      options nvidia NVreg_EnablePCIeGen3=1
      options nvidia NVreg_EnableGpuFirmware=0
    '';
  };
}