{ config, pkgs, ... }:

let
  # tvm-ffi C++ headers needed by flashinfer JIT compilation
  tvmFfiHeaders = pkgs.fetchFromGitHub {
    owner = "mlc-ai";
    repo = "tvm-ffi";
    rev = "583e4b73c11aa3257e7be862834b98f33c39a6dd";
    hash = "sha256-h6Q9d0wrJLZnAqmHV5yM9N6HQ1+ucEE75GcLw05MSJQ=";
    fetchSubmodules = true;
  };

  # Python shim for tvm_ffi module (flashinfer 0.6.4+ requires it)
  tvmFfiShim = pkgs.writeTextDir "tvm_ffi/__init__.py" ''
    """tvm_ffi shim for flashinfer JIT compatibility."""

    class _LibInfo:
        @staticmethod
        def find_include_path():
            return "${tvmFfiHeaders}/include"

        @staticmethod
        def find_dlpack_include_path():
            return "${tvmFfiHeaders}/3rdparty/dlpack/include"

    libinfo = _LibInfo()

    def register_func(name, func=None, override=False):
        if func: return func
        return lambda f: f

    def load_module(path):
        import ctypes
        return ctypes.CDLL(str(path))

    def get_global_func(name, allow_missing=False):
        return None
  '';
in
{
  sops.secrets.huggingface_token = {
    sopsFile = ../secrets/secrets.yaml;
    owner = "vllm";
    group = "vllm";
  };

  systemd.services.vllm = {
    description = "vLLM OpenAI-compatible API server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    environment = {
      HOME = "/var/lib/vllm";
      HF_TOKEN_PATH = "${config.sops.secrets.huggingface_token.path}";
      PYTHONPATH = "${tvmFfiShim}";
      CUDA_HOME = "${pkgs.cudaPackages.cudatoolkit}";
      CUDACXX = "${pkgs.cudaPackages.cudatoolkit}/bin/nvcc";
      CC = "${pkgs.gcc14}/bin/gcc";
      CXX = "${pkgs.gcc14}/bin/g++";
      LD_LIBRARY_PATH = "${pkgs.cudaPackages.cudatoolkit}/lib:${config.hardware.nvidia.package}/lib";
      LIBRARY_PATH = "${pkgs.cudaPackages.cudatoolkit}/lib:${pkgs.cudaPackages.cudatoolkit}/lib/stubs:${config.hardware.nvidia.package}/lib";
    };

    path = [
      pkgs.gcc14
      pkgs.binutils
      pkgs.cudaPackages.cudatoolkit
      pkgs.ninja
    ];

    serviceConfig = {
      Type = "simple";
      User = "vllm";
      Group = "vllm";
      ExecStart = "${pkgs.vllm}/bin/vllm serve numind/NuExtract3 --served-model-name numind/NuExtract3 --host 0.0.0.0 --port 8000 --gpu-memory-utilization 0.45 --max-model-len 8192 --max-num-seqs 8";
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };

  users.users.vllm = {
    isSystemUser = true;
    group = "vllm";
    home = "/var/lib/vllm";
    createHome = true;
  };

  users.groups.vllm = {};
}
