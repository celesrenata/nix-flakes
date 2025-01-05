{ ... }:
{
  config = {
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
    #boot.kernelPackages = pkgs.t2Kernel;
    boot.kernelModules = [ "uinput" "amdgpu" ];
  };
}