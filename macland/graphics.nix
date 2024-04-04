{ pkgs, ... }:
{
  config = {
    # Enable OpenGL
      hardware.opengl = {
        enable = true;
        driSupport = true;
        driSupport32Bit = true;
        extraPackages = [ pkgs.vaapiVdpau pkgs.libvdpau-va-gl pkgs.amdvlk ];
        extraPackages32 = [ pkgs.driversi686Linux.amdvlk ];
      };

      # Load AMD driver for Xorg and Wayland
      environment.variables.LIBVA_DRIVER_NAME = "amdgpu";
      services.xserver.videoDrivers = ["amdgpu"];
      hardware.nvidia.prime = { 
        sync.enable = true; 
      
        # Bus ID of the AMD GPU. You can find it using lspci, either under 3D or VGA 
        amdgpuBusId = "PCI:3:0:0"; 
      
        # Bus ID of the Intel GPU. You can find it using lspci, either under 3D or VGA 
        intelBusId = "PCI:0:2:0"; 
      };
  };
}