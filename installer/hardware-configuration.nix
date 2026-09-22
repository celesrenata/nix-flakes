{ ... }: {
  # Replaced by install-portable.sh after the target disk is partitioned.
  fileSystems."/" = { device = "/dev/disk/by-label/nixos"; fsType = "btrfs"; };
  fileSystems."/boot" = { device = "/dev/disk/by-label/EFI"; fsType = "vfat"; };
}
