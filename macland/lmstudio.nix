{ config, lib, ... }:

{
  # Override lmstudio to 0.4.6-1 for macland
  # Access the pkgs from specialArgs that has allowUnfree
  environment.systemPackages = let
    pkgs = config._module.specialArgs.pkgs;
  in [
    (pkgs.lmstudio.overrideAttrs (old: rec {
      version = "0.4.6-1";
      src = pkgs.fetchurl {
        url = "https://installers.lmstudio.ai/linux/x64/${version}/LM-Studio-${version}-x64.AppImage";
        hash = "sha256-FHZ64zmnqHrQyX4ift/lVUzW+HiCVkXpWVa4hkssX/k=";
      };
    }))
  ];
}
