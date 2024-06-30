{ ... }:
{
  config = {
    # Enable VMWare Tools.
    virtualisation.docker.enable = true;
    # Enable QEMU.
    virtualisation.libvirtd.enable = true;
    programs.virt-manager.enable = true;
  };
}
