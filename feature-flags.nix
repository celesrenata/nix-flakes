# NixOS Experimental Configuration - Feature Flags
# 
# ALL FEATURES ENABLED - Full production configuration
# Use this for maximum feature set (will take longer to build!)

{ config, lib, pkgs, ... }:

let
  # ============================================================================
  # CORE SYSTEM FEATURES (ALWAYS TRUE - NEVER DISABLE)
  # ============================================================================
  
  enableCoreSystem = true;        # Essential system services, user setup, bootloader
  
  # ============================================================================
  # DESKTOP ENVIRONMENT FEATURES
  # ============================================================================
  
  enableDesktopEnvironment = true;   # Hyprland window manager and Quickshell
  enableToucheggGestures = true;      # Touchégg gesture support (for touchpads)
  enableKeydRemapping = true;          # keyd keyboard remapping daemon
  enableTheming = true;                # Custom cursors, GTK themes, appearance
  
  # ============================================================================
  # GAMING & ENTERTAINMENT FEATURES
  # ============================================================================
  
  enableGaming = true;             # Steam, Protontricks, GameMode, Mangohud
  enableVRSupport = true;          # ALVR, WiVRn for VR streaming
  enableMediaPlayers = true;       # mpv, vlc, Spotify, Tidal-Hifi, etc.
  
  # ============================================================================
  # DEVELOPMENT TOOLS FEATURES (VERY HEAVY!)
  # ============================================================================
  
  enableDevelopmentTools = true;   # VSCode, JetBrains, compilers, languages
  
  # Sub-categories for development:
  enableVSCode = true;              # VSCode with extensions
  enableJetBrains = true;           # JetBrains Toolbox
  enablePythonDev = true;           # Python + CUDA support (VERY HEAVY!)
  enableNodeJS = true;              # Node.js and npm packages
  enableJava = true;                # OpenJDK
  enableCMakeBuildTools = true;     # CMake, Meson, Ninja
  enableKubernetes = true;          # k3s, Helm, Kustomize (VERY HEAVY!)
  
  # ============================================================================
  # AI & MACHINE LEARNING FEATURES (EXTREMELY HEAVY!)
  # ============================================================================
  
  enableAIService = true;           # Ollama local LLM server
  
  # Sub-categories for AI:
  enableOllama = true;              # Local LLM inference with CUDA/ROCm (VERY VERY HEAVY!)
  enableComfyUI = true;             # ComfyUI image generation service (HEAVY!)
  enableMCP = true;                 # Model Context Protocol servers (MODERATE)
  
  # ============================================================================
  # VIRTUALIZATION & CONTAINERS
  # ============================================================================
  
  enableVirtualization = true;      # Docker, QEMU/KVM, libvirt
  
  # Sub-categories for virtualization:
  enableDocker = true;              # Docker with NVIDIA support
  enableQEMU = true;                # QEMU/KVM virtualization
  enableWindowsVM = true;           # Pre-configured Windows VM container
  
  # ============================================================================
  # SYSTEM MONITORING & UTILITIES
  # ============================================================================
  
  enableMonitoringTools = true;     # btop, iotop, iftop, strace, etc.
  enableRemoteAccess = true;        # FreeRDP, wlvncc for remote desktop
  
  # ============================================================================
  # AUDIO & SOUND FEATURES
  # ============================================================================
  
  enableAudioEffects = true;        # EasyEffects, LADSPA plugins
  enableMacBookT2Audio = false;     # MacBook T2-specific audio processing (macland only)
  
  # ============================================================================
  # PLATFORM-SPECIFIC FEATURES
  # ============================================================================
  
  # NVIDIA features (esnixi):
  enableNVIDIA = true;              # NVIDIA drivers, CUDA support
  
  # AMD/ROCm features (macland):
  enableAMDGPU = false;             # AMD GPU with ROCm support (esnixi only)
  
  # MacBook T2 specific:
  enableMacBookT2 = false;          # T2 chip, Touch Bar, fan control (macland only)
  
  # ============================================================================
  # SECURITY & PRIVACY FEATURES
  # ============================================================================
  
  enableSecurityFeatures = true;    # Firewall, SOPS secrets management
  enableBluetooth = true;           # Bluetooth support with Blueman
  
  # ============================================================================
  # OPTIONAL TOOLS (LOW IMPACT)
  # ============================================================================
  
  enableOptionalTools = true;       # Low-impact utilities that are generally useful
  enableFonts = true;               # Extended font packages
  enableGitLFS = true;              # Git LFS support
  
in

{
  config = {
    # ============================================================================
    # CORE SYSTEM (Always enabled or explicitly set)
    # ============================================================================
    
    nixpkgs.hostPlatform = "x86_64-linux";
    environment.localBinInPath = true;
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    time.timeZone = "America/Los_Angeles";
    i18n.defaultLocale = "en_US.UTF-8";
    
    # User setup (always needed)
    users.users.celes.isNormalUser = true;
    users.users.celes.extraGroups = [ "wheel" ];  # Base group, others added conditionally
    
    # ============================================================================
    # DESKTOP ENVIRONMENT (Conditional - ALL ENABLED ABOVE)
    # ============================================================================
    
    services.xserver.enable = lib.mkDefault enableDesktopEnvironment;
    services.displayManager.gdm.enable = lib.mkDefault enableDesktopEnvironment;
    services.displayManager.defaultSession = "hyprland";
    
    programs.hyprland.enable = lib.mkDefault enableDesktopEnvironment;
    programs.fish.enable = lib.mkDefault (enableDesktopEnvironment || true);  # Keep fish for shell
    
    # Touchégg gestures (touchpad support)
    services.touchegg.enable = lib.mkDefault enableToucheggGestures;
    
    # Keyboard remapping with keyd
    services.keyd.enable = lib.mkDefault enableKeydRemapping;
    
    # Font packages (low impact, generally useful)
    fonts.packages = lib.mkDefault [
      (pkgs.noto-fonts)
      (pkgs.noto-fonts-cjk-sans)
      (pkgs.noto-fonts-color-emoji)
      (pkgs.dejavu_fonts)
      (pkgs.nerd-fonts.dejavu-sans-mono)
    ] ++ lib.mkIf enableFonts [
      (pkgs.fira-code)
      (pkgs.material-symbols)
      (pkgs.bibata-cursors)
    ];
    
    # ============================================================================
    # GAMING & ENTERTAINMENT (Conditional - ALL ENABLED ABOVE)
    # ============================================================================
    
    programs.steam.enable = lib.mkDefault enableGaming;
    programs.gamemode.enable = lib.mkDefault enableGaming;
    programs.alvr.enable = lib.mkDefault enableVRSupport;
    services.wivrn.enable = lib.mkDefault enableVRSupport;
    
    # Media players (conditional)
    home.packages = lib.mkIf enableMediaPlayers [
      pkgs.mpv
      pkgs.vlc
      pkgs.spotify
      pkgs.tidal-hifi
      pkgs.discord
    ];
    
    # ============================================================================
    # DEVELOPMENT TOOLS (Conditional - ALL ENABLED ABOVE) **VERY HEAVY!**
    # ============================================================================
    
    programs.git.enable = lib.mkDefault enableGitLFS;
    programs.git.lfs.enable = lib.mkDefault enableGitLFS;
    
    # VSCode and JetBrains (IDEs)
    programs.vscode.enable = lib.mkDefault (enableDevelopmentTools && enableVSCode);
    programs.jetbrains-toolbox.enable = lib.mkDefault (enableDevelopmentTools && enableJetBrains);
    
    # Python development with CUDA support
    environment.systemPackages = lib.mkIf (enableDevelopmentTools && enablePythonDev) [
      pkgs.python312.withPackages(ps: with ps; [
        torch
        torchvision
        torchaudio
        diffusers
        transformers
        accelerate
        huggingface-hub
        xformers
      ])
    ];
    
    # Node.js development
    environment.systemPackages = lib.mkIf (enableDevelopmentTools && enableNodeJS) [
      pkgs.nodejs_20
    ];
    
    # Java development
    programs.java.enable = lib.mkDefault (enableDevelopmentTools && enableJava);
    
    # CMake build tools
    environment.systemPackages = lib.mkIf (enableDevelopmentTools && enableCMakeBuildTools) [
      pkgs.cmake
      pkgs.meson
      pkgs.ninja
    ];
    
    # Kubernetes tools (can be heavy, optional)
    environment.systemPackages = lib.mkIf (enableDevelopmentTools && enableKubernetes) [
      pkgs.k3s
      pkgs.kubernetes-helm-wrapped
      pkgs.helmfile-wrapped
      pkgs.kustomize
      pkgs.kompose
    ];
    
    # ============================================================================
    # AI & MACHINE LEARNING (Conditional - ALL ENABLED ABOVE) **VERY VERY HEAVY!**
    # ============================================================================
    
    services.ollama.enable = lib.mkDefault enableAIService;
    
    if enableOllama then {
      users.users.ollama = {
        isSystemUser = true;
        group = "ollama";
        extraGroups = [ "video" "render" ];
      };
      users.groups.ollama = {};
      
      environment.systemPackages = lib.mkDefault [
        pkgs.cudaPackages.cudatoolkit
      ];
    } else {
      # Disable Ollama-related packages if not enabled
      services.ollama.enable = false;
    }
    
    # ComfyUI (AI image generation - heavy)
    environment.systemPackages = lib.mkIf enableComfyUI [
      pkgs.comfyui
    ];
    
    # MCP servers (Model Context Protocol - moderate impact)
    home.file.".kiro/settings/mcp.json" = lib.mkDefault enableMCP;
    home.file.".aws/amazonq/mcp.json" = lib.mkDefault enableMCP;
    
    # ============================================================================
    # VIRTUALIZATION & CONTAINERS (Conditional - ALL ENABLED ABOVE)
    # ============================================================================
    
    virtualisation.docker.enable = lib.mkDefault enableVirtualization && lib.mkDefault enableDocker;
    virtualisation.libvirtd.enable = lib.mkDefault enableVirtualization && lib.mkDefault enableQEMU;
    
    if enableWindowsVM then {
      virtualisation.oci-containers.containers.windows.autoStart = true;
    } else {
      virtualisation.oci-containers.containers.windows.autoStart = false;
    }
    
    # ============================================================================
    # MONITORING & REMOTE ACCESS (Optional - ALL ENABLED ABOVE)
    # ============================================================================
    
    environment.systemPackages = lib.mkIf enableMonitoringTools [
      pkgs.btop
      pkgs.iotop
      pkgs.iftop
      pkgs.strace
      pkgs.lsof
      pkgs.sysstat
    ];
    
    environment.systemPackages = lib.mkIf enableRemoteAccess [
      pkgs.freerdp
      pkgs.wayvnc
    ];
    
    # ============================================================================
    # AUDIO & SOUND (Conditional - ALL ENABLED ABOVE)
    # ============================================================================
    
    services.pipewire.enable = lib.mkDefault true;  # Always keep PipeWire
    services.easyeffects.enable = lib.mkDefault enableAudioEffects;
    
    # MacBook T2 audio processing (platform-specific, disabled by default)
    # This would be enabled only for macland platform with specific hardware
    
    # ============================================================================
    # PLATFORM-SPECIFIC FEATURES
    # ============================================================================
    
    # NVIDIA support (esnixi platform)
    hardware.nvidia.enable = lib.mkDefault enableNVIDIA;
    services.xserver.videoDrivers = lib.mkIf enableNVIDIA [ "nvidia" ];
    
    # AMD/ROCm support (macland platform)
    nixpkgs.config.rocmSupport = lib.mkDefault enableAMDGPU;
    
    # MacBook T2 features (platform-specific, disabled by default)
    services.hardware.bolt.enable = lib.mkDefault false;  # Thunderbolt (T2 specific)
    boot.kernelModules = lib.mkIf enableMacBookT2 [ "apple-bce" ];
    
    # ============================================================================
    # SECURITY & PRIVACY
    # ============================================================================
    
    networking.firewall.enable = lib.mkDefault true && lib.mkDefault enableSecurityFeatures;
    hardware.bluetooth.enable = lib.mkDefault enableBluetooth;
    services.blueman.enable = lib.mkDefault enableBluetooth;
    
    # SOPS secrets management (can be disabled if not needed)
    sops-nix.nixosModules.sops.enable = lib.mkDefault enableSecurityFeatures;
    
  };
  
  home-manager.users.celes.home.packages = [
    # Always include these core utilities
    pkgs.wl-clipboard
    pkgs.cliphist
    pkgs.hyprpicker
    
    # Conditional packages based on features
  ] ++ lib.mkIf enableOptionalTools [
    pkgs.fuzzel
    pkgs.ydotool
    pkgs.wtype
    pkgs.gz
  ];

}
