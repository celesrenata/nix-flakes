{ lib, pkgs, config, ... }:
let
  runtime = import ./gpu-runtime.nix { inherit pkgs; };
  admission = pkgs.writeTextDir "__init__.py" (builtins.readFile ./comfy_gpu_admission.py);
  workerLaunch = pkgs.writeTextDir "arcane_worker_launch.py" (builtins.readFile ./arcane_worker_launch.py);
  data = "/var/lib/comfyui-esnixi";
  arcaneData = "/var/lib/arcane-atlas";
  gpuLock = "/run/arcane-gpu/5090.lock";
  # On-demand ComfyUI: clients use the socket-activated gate on comfyGatePort;
  # the container (published on comfyBackendPort) runs only while the gate has
  # seen a connection within comfyIdleExit.
  comfyGatePort = 28188;
  comfyBackendPort = 28189;
  comfyIdleExit = "30s";
  # Never create the container while a vLLM unit holds the 5090 lease. Waits
  # indefinitely (the unit has TimeoutStartSec=0); gpu_launch.py inside the
  # container re-takes the lease before ComfyUI imports torch.
  waitForGpuLease = pkgs.writeShellScript "comfy-esnixi-wait-gpu-lease" ''
    exec ${pkgs.util-linux}/bin/flock ${gpuLock} ${pkgs.coreutils}/bin/true
  '';
  # Hold the gate's start (and so the client's pending connection) until
  # ComfyUI answers HTTP.
  waitForComfy = pkgs.writeShellScript "comfy-esnixi-wait-ready" ''
    until ${pkgs.curl}/bin/curl -fsS -o /dev/null --max-time 5 \
        http://127.0.0.1:${toString comfyBackendPort}/queue; do
      sleep 1
    done
  '';
in
{
  # gpu_launch.py opens the 0660 root:vllm lease file as the container's uid
  # 1000, so the container needs the vllm gid as a supplementary group. Pinned
  # to the gid NixOS already allocated so the lease file keeps its group.
  users.groups.vllm.gid = 978;

  virtualisation.oci-containers.containers.comfy-esnixi = {
    # Started by comfy-esnixi-gate.socket on the first connection, stopped
    # (StopWhenUnneeded) when the gate exits after comfyIdleExit without one.
    autoStart = false;
    image = "registry.celestium.life/comfyui/worker@sha256:9d5bcb958db788d4a48c5b206adf4cbb564925dbf7bf4872b22a1c4a028a3857";
    user = "1000:1000";
    ports = [ "127.0.0.1:${toString comfyBackendPort}:8188" ];
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
      AA_COMFY_IDLE_UNLOAD_SECONDS = "5";
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
      "--group-add=${toString config.users.groups.vllm.gid}"
    ];
  };
  virtualisation.oci-containers.containers.arcane-atlas-esnixi-worker = {
    # Both queue consumers use the shared NFS lease in the active worker script.
    autoStart = true;
    image = "registry.celestium.life/comfyui/worker@sha256:9d5bcb958db788d4a48c5b206adf4cbb564925dbf7bf4872b22a1c4a028a3857";
    user = "1000:1000";
    entrypoint = "/opt/venv/bin/python";
    # The launcher runs the unmodified NFS worker script, but makes each job
    # wait (indefinitely) for on-demand ComfyUI and own the GPU lease for its
    # whole run. AA_WORKER_SCRIPT defaults to the path below.
    cmd = [ "/opt/arcane-worker/arcane_worker_launch.py" ];
    volumes = [
      "${workerLaunch}:/opt/arcane-worker:ro"
      "${arcaneData}:/data"
      "${arcaneData}/warm/celes:/warm"
      "${data}/venv:/opt/venv:ro"
    ];
    environment = {
      PYTHONPATH = "/data/arcane-atlas/system/arcane-atlas-card-factory/src";
      AA_NEXTCLOUD_ROOT = "/data/arcane-atlas";
      AA_COMFY_URL = "http://127.0.0.1:${toString comfyGatePort}";
      # The VLM only derives and audits a generation contract.  It does not
      # replace user intent, and the endpoint is bound to host loopback.
      AA_VLM_URL = "http://127.0.0.1:8011";
      AA_VLM_MODEL = "qwen2.5-vl-7b-instruct";
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
    unitConfig.StopWhenUnneeded = true;
    serviceConfig = {
      # After the module's own pre-start (container cleanup).
      ExecStartPre = lib.mkAfter [ "${waitForGpuLease}" ];
      ExecStartPost = [ "${waitForComfy}" ];
    };
  };

  # Socket-activated front door for ComfyUI. The first connection starts
  # comfy-esnixi-gate.service, which requires (and is ordered after) the
  # container, so the connection is held until ComfyUI is up. The proxy exits
  # after comfyIdleExit without connections, which stops the container: no
  # CUDA context, VRAM or host RAM while idle.
  systemd.sockets.comfy-esnixi-gate = {
    description = "On-demand ComfyUI listener for the RTX 5090";
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "127.0.0.1:${toString comfyGatePort}" ];
  };
  systemd.services.comfy-esnixi-gate = {
    description = "Forward ComfyUI connections to the on-demand container";
    requires = [ "comfy-esnixi-gate.socket" "docker-comfy-esnixi.service" ];
    after = [ "comfy-esnixi-gate.socket" "docker-comfy-esnixi.service" ];
    serviceConfig = {
      ExecStart = "${config.systemd.package}/lib/systemd/systemd-socket-proxyd --exit-idle-time=${comfyIdleExit} 127.0.0.1:${toString comfyBackendPort}";
      DynamicUser = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };
  systemd.services.vllm-nvidia-cdi.before = [ "docker-comfy-esnixi.service" ];
  fileSystems."/var/lib/arcane-atlas" = {
    device = "192.168.42.8:/volume1/Kubernetes/comfyui/data";
    fsType = "nfs";
    options = [ "vers=4.1" "noac" ];
  };

}
