{ pkgs }:
pkgs.runCommand "arcane-gpu-runtime" { } ''
  mkdir -p $out
  cp ${./arcane_gpu.py} $out/arcane_gpu.py
  cp ${./gpu_launch.py} $out/gpu_launch.py
  cp ${./vllm_idle.py} $out/vllm_idle.py
''
