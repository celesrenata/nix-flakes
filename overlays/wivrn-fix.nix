final: prev: {
  wivrn = prev.wivrn.overrideAttrs (oldAttrs: rec {
    version = "26.2.3";
    src = prev.fetchFromGitHub {
      owner = "wivrn";
      repo = "wivrn";
      rev = "v26.2.3";
      hash = "sha256-pU7FYPp5wa0MK0ut/BfFlnUai8yMcylpWC0CoAExAio=";
    };
    monado = prev.applyPatches {
      src = prev.fetchFromGitLab {
        domain = "gitlab.freedesktop.org";
        owner = "monado";
        repo = "monado";
        rev = "723652b545a79609f9f04cb89fcbf807d9d6451a";
        hash = "sha256-wGqvTI/X22apc8XCN3GCGQClHfBW5xk73mZnwWvHtyI=";
      };
      postPatch = ''
        ${src}/patches/apply.sh ${src}/patches/monado/*
      '';
    };
  });
}
