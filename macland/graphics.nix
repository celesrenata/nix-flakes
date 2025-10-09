{ pkgs, pkgs-unstable, lib, ... }:

{
  config = {
    # Enable OpenGL
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = [ pkgs.libva-vdpau-driver pkgs.libvdpau-va-gl pkgs.amdvlk ];
      extraPackages32 = [ pkgs.driversi686Linux.amdvlk ];
    };

    # Load AMD driver for Xorg and Wayland
    environment.variables.LIBVA_DRIVER_NAME = "amdgpu";
    environment.variables.VDPAU_DRIVER = "amdgpu";
    services.xserver.videoDrivers = ["amdgpu"];
    hardware.nvidia.prime = { 
      sync.enable = true; 
    
      # Bus ID of the AMD GPU. You can find it using lspci, either under 3D or VGA 
      amdgpuBusId = "PCI:3:0:0"; 
    
      # Bus ID of the Intel GPU. You can find it using lspci, either under 3D or VGA 
      intelBusId = "PCI:0:2:0"; 
    };
    # ROCm symlink with fixed packages
    # services.ollama = {
    #   package = pkgs-unstable.ollama;
    #   enable = true;
    #   # Keep acceleration disabled until we fully resolve the CLR dependency issue
    #   acceleration = "rocm";  # Temporarily disabled until we fix the CLR dependency issue
    #   #listenAddress = "0:0:0:0:11434";
    #   host = "0.0.0.0";
    #   port = 11434;
    #   environmentVariables = {
    #     HSA_OVERRIDE_GFX_VERSION = "10.1.0";
    #   };
    # #      models = "/opt/ollama/models";
    # };
    security.wrappers.sunshine = {
        owner = "root";
        group = "root";
        capabilities = "cap_sys_admin+p";
        source = "${pkgs-unstable.sunshine}/bin/sunshine";
    };
    security.wrappers.immersed = {
        owner = "root";
        group = "root";
        capabilities = "cap_sys_admin+p";
        source = "${pkgs.immersed}/bin/immersed";
    };
  };
}
