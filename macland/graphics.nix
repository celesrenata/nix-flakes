{ pkgs, ... }:
{
  config = {
    # Enable OpenGL
    hardware.opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
      extraPackages = with pkgs; [ vaapiVdpau pkgs.libvdpau-va-gl amdvlk rocmPackages.clr.icd ];
      extraPackages32 = with pkgs; [ driversi686Linux.amdvlk ];
    };

    # Load AMD driver for Xorg and Waylandard
    environment.variables.LIBVA_DRIVER_NAME = "amdgpu";
    environment.variables.VDPAU_DRIVER = "amdgpu";
    services.xserver.videoDrivers = ["amdgpu"];
    hardware.amdgpu.opencl.enable = true;
    hardware.nvidia.prime = { 
      sync.enable = true; 
    
      # Bus ID of the AMD GPU. You can find it using lspci, either under 3D or VGA 
      amdgpuBusId = "PCI:3:0:0"; 
    
      # Bus ID of the Intel GPU. You can find it using lspci, either under 3D or VGA 
      intelBusId = "PCI:0:2:0"; 
    };

    systemd.tmpfiles.rules = 
    let
      rocmEnv = pkgs.symlinkJoin {
        name = "rocm-combined";
        paths = with pkgs.rocmPackages; [
          rocblas
          hipblas
          clr
        ];
      };
    in [
      "L+    /opt/rocm   -    -    -     -    ${rocmEnv}"
    ];
    
    services.ollama = {
      enable = true;
      acceleration = "rocm";
      environmentVariables = {
        HSA_OVERRIDE_GFX_VERSION = "10.1.2";
      };
#      models = "/opt/ollama/models";
    };
    environment.systemPackages = [
      pkgs.xivlauncher
    ];
  };
}
