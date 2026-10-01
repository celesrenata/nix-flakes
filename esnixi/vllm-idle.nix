{ lib, pkgs, ... }:

{
  systemd.services.arcane-gpu-lock = {
    description = "Shared RTX 5090 ownership file";
    # docker-vllm-5090 was retired (replaced by the native dormant
    # vllm-5090-fallback unit); drop the dangling ordering dep. docker-comfy-esnixi
    # is kept only if that unit still exists elsewhere (systemd ignores an ordering
    # dep on an absent unit, so this is harmless either way).
    before = [ "docker-comfy-esnixi.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      RuntimeDirectory = "arcane-gpu";
      RuntimeDirectoryMode = "0755";
      RuntimeDirectoryPreserve = "yes";
    };
    # Never replace the inode while any holder might have a lease.
    # Owner root, group vllm, mode 0660: the native leaseWrap'd vLLM units run as
    # user `vllm` and gpu_launch.py re-opens this file O_RDWR, so `vllm` needs group
    # read/write. The vision container opens it as host root (Docker, no userns-remap)
    # and so can open it regardless of mode/owner. (Previous `-o 1000 -g 1000 -m 0600`
    # only worked because the vision container is root; the native `vllm` user is a
    # system uid, not uid 1000, and would EACCES under 0600.)
    script = ''
      if [ ! -e /run/arcane-gpu/5090.lock ]; then
        ${pkgs.coreutils}/bin/install -m 0660 -o root -g vllm /dev/null /run/arcane-gpu/5090.lock
      fi
    '';
  };
}
