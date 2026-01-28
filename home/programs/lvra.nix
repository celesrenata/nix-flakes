{ config, pkgs, ... }:

{
  # Make the OpenXR active runtime file a link to a nix-store path
  # so Steam's sandbox can access the target. :contentReference[oaicite:7]{index=7}
  xdg.configFile."openxr/1/active_runtime.json".source =
    "${pkgs.wivrn}/share/openxr/1/openxr_wivrn.json";

  # If you want Monado instead, LVRA shows this variant. :contentReference[oaicite:8]{index=8}
  # xdg.configFile."openxr/1/active_runtime.json".source =
  #   "${pkgs.monado}/share/openxr/1/openxr_monado.json";
  
  xdg.configFile."openvr/openvrpaths.vrpath".text = let
    steam = "${config.xdg.dataHome}/Steam";
  in builtins.toJSON {
    version = 1;
    jsonid = "vrpathreg";

    external_drivers = null;
    config = [ "${steam}/config" ];
    log = [ "${steam}/logs" ];

    runtime = [
      "${pkgs.xrizer}/lib/xrizer"
      # OR:
      # "${pkgs.opencomposite}/lib/opencomposite"
    ];
  };
}

