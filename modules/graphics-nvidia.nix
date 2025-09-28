{ config, lib, pkgs, inputs, hasNvidia ? false, ... }:
let
  nvidia-package = config.boot.kernelPackages.nvidiaPackages.mkDriver ({
    version = "580.82.07";
    sha256_64bit = "sha256-Bh5I4R/lUiMglYEdCxzqm3GLolQNYFB0/yJ/zgYoeYw=";
    sha256_aarch64 = "";
    openSha256 = "sha256-8/7ZrcwBMgrBtxebYtCcH5A51u3lAxXTCY00LElZz08=";
    settingsSha256 = "sha256-lx1WZHsW7eKFXvi03dAML6BoC5glEn63Tuiz3T867nY=";
    persistencedSha256 = "sha256-1JCk2T3H5NNFQum0gA9cnio31jc0pGvfGIn2KkAz9kA=";
  });
in {
  # NVIDIA-only headless server with stability improvements

  # Optimized kernel parameters for CUDA containers + containerd + k3s
  boot.kernelParams = [
    "intel_iommu=on"              # ensure IOMMU active
    "iommu=pt"                    # pass-through mapping; lowers overhead / flakiness
    "modprobe.blacklist=i915,xe"  # keep Intel gfx out on this node
    "pcie_aspm=off"               # disable PCIe ASPM to prevent Xid/link errors
    "nmi_watchdog=0"              # disable NMI watchdog to prevent panic reboots
    "softlockup_panic=0"          # disable softlockup panic to prevent reboots
    "nvidia-drm.modeset=0"        # disable KMS on headless server
  ];

  # Blacklist Intel graphics modules + nouveau for stability
  boot.blacklistedKernelModules = [ "i915" "xe" "intel_guc_submission" "nouveau" ];

  # Add NVIDIA-specific overlays
  nixpkgs.overlays = [
    (import ../overlays/nvidia-container-toolkit.nix)
  ];

  # Add NVIDIA-specific packages
  environment.systemPackages = with pkgs; [
    nvidia-container-toolkit
    nvtopPackages.full
  ];

  # CDI-based container runtime configuration
  virtualisation.containerd.enable = true;
  hardware.nvidia-container-toolkit.enable = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = [ ];
  };
    
  # NVIDIA headless server configuration
  hardware.nvidia = {
    package = nvidia-package;
    nvidiaPersistenced = false;
    powerManagement.enable = false;
    open = true;
    nvidiaSettings = true;
    modesetting.enable = false;       # disable KMS on headless server
    prime.offload.enable = false;
  };

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.enableRedistributableFirmware = true;
  hardware.enableAllFirmware = true;

  services.xserver = {
    enable = false;                   # headless server
    videoDrivers = [ "nvidia" ];
  };
}
