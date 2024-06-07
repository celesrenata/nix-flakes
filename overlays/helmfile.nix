final: prev: rec {
  kubernetes-helm-wrapped = prev.wrapHelm prev.kubernetes-helm {
    plugins = with prev.kubernetes-helmPlugins; [
      helm-diff
      helm-secrets
      helm-s3
    ];
  };
}
