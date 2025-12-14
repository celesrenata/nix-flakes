{ config, pkgs, lib, ... }:
{
  config.system.nixos.tags = let
    cfg = config.boot.loader.raspberryPi;
  in [
    "raspberry-pi${cfg.variant}"
    cfg.bootloader
    config.boot.kernelPackages.kernel.version
  ];
  config.zramSwap.enable = true;
}

