final: prev:
rec {
  sunshineOverride = prev.sunshine.overrideAttrs (old: {
    cudaSupport = true;

    runtimeDependencies = old.runtimeDependencies ++ [ 
      prev.linuxKernel.packages.linux_zen.nvidia_x11
    ];
    shellHook = ''
      export CUDA_PATH=${prev.cudatoolkit}
    '';
  });
}
