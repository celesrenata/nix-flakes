final: prev:
{
  inherit (prev.system) linux_rpi5;
  rtl8821cuOverride = prev.stdenv.mkDerivation rec {
    pname = "rtl8821cu";
    #version = "${prev.system.kernel.modDirVersion}-unstable-2024-05-30";
    version = "6.6.31-unstable-2024-05-30";
  
    src = prev.fetchFromGitHub {
      owner = "morrownr";
      repo = "8821cu-20210916";
      rev = "f6d4598290c5e9c8e545130e8a31d130f6d135f4";
      hash = "sha256-jpMf8K9diJ3mbEkP9Cp+VwairK+pwiEGU/AtUIouCqM=";
    };
  
    hardeningDisable = [ "pic" ];
  
    nativeBuildInputs = [ prev.bc ] ++ prev.system.kernel.moduleBuildDependencies;
    makeFlags = prev.system.kernel.makeFlags;
  
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
