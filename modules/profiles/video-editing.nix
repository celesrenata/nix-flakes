{ config, lib, pkgs, ... }:

{
  config = lib.mkIf config.my.profiles.videoEditing.enable {
    environment.systemPackages = with pkgs; [
      kdePackages.kdenlive
      ffmpeg-full
      mkvtoolnix-cli
      darktable
      blender
    ];
  };
}
