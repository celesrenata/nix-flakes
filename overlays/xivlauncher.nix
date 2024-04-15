final: prev:
let
  unstable = import <nixos-unstable> { config = { allowUnfree = true; }; };
in {
  prev.environment.systemPackages = [
    unstable.xivlauncher
  ];
}