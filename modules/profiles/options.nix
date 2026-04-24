{ config, lib, ... }:

{
  options.my = {
    profiles = {
      games.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable gaming profile (Steam, Proton, ALVR, gamemode).";
      };

      development.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable development profile (compilers, build tools, language runtimes).";
      };

      videoEditing.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable video editing profile (kdenlive, ffmpeg, blender).";
      };

      virtualization.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable virtualization profile (Docker, QEMU/KVM, libvirtd).";
      };

      ai.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable AI/ML profile (Ollama, vLLM, CUDA/ROCm workloads).";
      };
    };

    acceleration.backend = lib.mkOption {
      type = lib.types.enum [ "cuda" "rocm" "cpu" ];
      default = "cpu";
      description = "Hardware acceleration backend for AI workloads.";
    };

    paths = {
      dockerData = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/docker";
        description = "Root data directory for the Docker daemon.";
      };

      ollamaHome = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/ollama";
        description = "Home directory for the Ollama service.";
      };

      ollamaModels = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/ollama/models";
        description = "Directory where Ollama stores downloaded models.";
      };

      vllmHome = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/vllm";
        description = "Home directory for the vLLM service.";
      };

      vllmModels = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/vllm/models";
        description = "Directory where vLLM stores downloaded models.";
      };

      buildScratch = lib.mkOption {
        type = lib.types.str;
        default = "/var/tmp/nix-build";
        description = "Scratch directory for Nix builds.";
      };
    };
  };
}
