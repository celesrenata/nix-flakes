final: prev: {
  linuxPackages_latest = prev.linuxPackages_latest // {
    nvidia_x11 = prev.linuxPackages_latest.nvidia_x11.overrideAttrs (old: {
      patches = (old.patches or []) ++ [
        ./patches/nvidia-6.16-vm-flags.patch
      ];
    });
  };
}
