{ pkgs, config, ... }:
let
  runtime = import ./gpu-runtime.nix { inherit pkgs; };
  admission = pkgs.writeTextDir "__init__.py" (builtins.readFile ./comfy_gpu_admission.py);
  data = "/var/lib/comfyui-esnixi";
  arcaneData = "/var/lib/arcane-atlas";
in
{
  virtualisation.oci-containers.containers.comfy-esnixi = {
    autoStart = true;
    image = "registry.celestium.life/comfyui/worker@sha256:9d5bcb958db788d4a48c5b206adf4cbb564925dbf7bf4872b22a1c4a028a3857";
    user = "1000:1000";
    ports = [ "127.0.0.1:28188:8188" ];
    entrypoint = "/opt/venv/bin/python";
    volumes = [
      "${data}/models:/opt/ComfyUI/models:ro"
      "${data}/venv:/opt/venv:ro"
      "${data}/custom-nodes:/opt/ComfyUI/custom_nodes:ro"
      "${admission}:/opt/ComfyUI/custom_nodes/arcane-gpu-admission:ro"
      "${data}/lora-cache:/opt/ComfyUI/models/SVDQLora"
      "${data}/data:/warm"
      "${runtime}:/opt/arcane-gpu:ro"
      "${pkgs.cudaPackages.cuda_cudart}/lib:/opt/cuda/lib:ro"
      "/run/arcane-gpu:/run/arcane-gpu"
    ];
    environment = {
      PYTHONPATH = "/app:/opt/arcane-gpu";
      LD_LIBRARY_PATH = "/opt/venv/lib/python3.12/site-packages/torch/lib:/opt/cuda/lib:${config.hardware.nvidia.package}/lib";
      ARCANE_GPU_LOCK = "/run/arcane-gpu/5090.lock";
    };
    cmd = [
      "/opt/arcane-gpu/gpu_launch.py"
      "/opt/venv/bin/python" "/opt/ComfyUI/main.py"
      "--listen" "0.0.0.0" "--port" "8188"
      "--input-directory" "/warm/input"
      "--output-directory" "/warm/output"
      "--temp-directory" "/warm/temp"
      "--user-directory" "/warm/user"
      "--disable-auto-launch" "--disable-api-nodes"
      "--use-pytorch-cross-attention"
      "--reserve-vram" "6.0"
    ];
    extraOptions = [
      "--device=nvidia.com/gpu=0"
      "--shm-size=2g"
      "--tmpfs=/tmp:rw,size=8g,uid=1000,gid=1000,mode=1777"
    ];
  };
  virtualisation.oci-containers.containers.arcane-atlas-esnixi-worker = {
    # Both queue consumers use the shared NFS lease in the active worker script.
    autoStart = true;
    image = "registry.celestium.life/comfyui/worker@sha256:9d5bcb958db788d4a48c5b206adf4cbb564925dbf7bf4872b22a1c4a028a3857";
    user = "1000:1000";
    entrypoint = "/opt/venv/bin/python";
    cmd = [ "/data/arcane-atlas/system/arcane-atlas-card-factory/scripts/nextcloud_queue_worker.py" ];
    volumes = [
      "${arcaneData}:/data"
      "${arcaneData}/warm/celes:/warm"
      "${data}/venv:/opt/venv:ro"
    ];
    environment = {
      PYTHONPATH = "/data/arcane-atlas/system/arcane-atlas-card-factory/src";
      AA_NEXTCLOUD_ROOT = "/data/arcane-atlas";
      AA_COMFY_URL = "http://127.0.0.1:28188";
      AA_ALLOWED_MODES = "new_character,regenerate_character,expand_character,existing_card,regenerate_card_art,art_only";
      AA_WORKER_TARGET = "5090";
      AA_DISPATCH_TARGET = "5090";
      AA_NUNCHAKU_QWEN_MODEL = "nunchaku_qwen_image_2512_balance_fp4.safetensors";
      AA_NUNCHAKU_EDIT_MODEL = "arcane-atlas/qwen-edit-2509-fp4-r128-8steps.safetensors";
      AA_NUNCHAKU_CPU_OFFLOAD = "disable";
      AA_WARM_ROOT = "/warm";
      PYTHONDONTWRITEBYTECODE = "1";
    };
    extraOptions = [ "--network=host" "--shm-size=2g" "--tmpfs=/tmp:rw,size=8g,uid=1000,gid=1000,mode=1777" ];
  };

  systemd.services.docker-comfy-esnixi = {
    after = [ "arcane-gpu-lock.service" "vllm-nvidia-cdi.service" ];
    requires = [ "arcane-gpu-lock.service" "vllm-nvidia-cdi.service" ];
  };
  systemd.services.vllm-nvidia-cdi.before = [ "docker-comfy-esnixi.service" ];
  fileSystems."/var/lib/arcane-atlas" = {
    device = "192.168.42.8:/volume1/Kubernetes/comfyui/data";
    fsType = "nfs";
    options = [ "vers=4.1" "noac" ];
  };

}
