final: prev:
{
  #inherit (prev.system) linux_rpi5;
  rtl8821au = prev.linuxKernel.packages.rtl8821au.override rec {
    pname = "rtl8821au-20210708";
    #version = "${prev.system.kernel.modDirVersion}-unstable-2024-05-30";
    version = "20240613";
  
    src = prev.fetchFromGitHub {
      owner = "morrownr";
      repo = "8821au-20210708";
      rev = "0b12ea54b7d6dcbfa4ce94eb403b1447565407f1";
      hash = "";
    };
  
    #hardeningDisable = [ "pic" "format" ];
  
    #nativeBuildInputs = with prev; [
    #  bc
    #  nukeReferences
    #] ++ prev.system.kernel.moduleBuildDependencies;
    #makeFlags = prev.system.kernel.makeFlags;
  
    # prePatch = ''
    #   substituteInPlace ./Makefile \
    #     --replace /lib/modules/ "${prev.kernel.dev}/lib/modules/" \
    #     --replace /sbin/depmod \# \
    #     --replace '$(MODDESTDIR)' "$out/lib/modules/${prev.kernel.modDirVersion}/kernel/net/wireless/"
    # '';
  
    # preInstall = ''
    #   mkdir -p "$out/lib/modules/${prev.kernel.modDirVersion}/kernel/net/wireless/"
    # '';
  
    # enableParallelBuilding = true;
  
    # meta = with prev.lib; {
    #   description = "Realtek rtl8821cu driver";
    #   homepage = "https://github.com/morrownr/8821cu";
    #   license = licenses.gpl2Only;
    #   platforms = platforms.linux;
    #   maintainers = [ maintainers.contrun ];
    # };
  };
}
