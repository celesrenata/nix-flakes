final: prev:
rec {
  argononedOverride = prev.stdenv.mkDerivation {
    pname = "argononedOverride";
    version = "0.5.x";
    src = prev.fetchFromGitLab {
      owner = "DarkElvenAngel";
      repo = "argononed";
      rev = "61eb4301c8981a71f607131743680838c782e168";
      sha256 = "sha256-Uv4cyo3FcHIr4N9s+A0ZMmQU7KYAiClcMOtZPXA6GQQ=";
    };

    postPatch = ''
      patchShebangs configure
    '';
  
    nativeBuildInputs = [ prev.installShellFiles ];
  
    buildInputs = [ prev.dtc ];
  
    installPhase = ''
      runHook preInstall
  
      install -Dm755 build/argononed $out/bin/argononed
      install -Dm755 build/argonone-cli $out/bin/argonone-cli
      install -Dm755 build/argonone-shutdown $out/lib/systemd/system-shutdown/argonone-shutdown
      install -Dm644 build/argonone.dtbo $out/boot/overlays/argonone.dtbo
  
      install -Dm644 OS/_common/argononed.service $out/lib/systemd/system/argononed.service
      install -Dm644 OS/_common/argononed.logrotate $out/etc/logrotate.d/argononed
      install -Dm644 LICENSE $out/share/argononed/LICENSE
  
      installShellCompletion --bash --name argonone-cli OS/_common/argonone-cli-complete.bash
  
      runHook postInstall
    '';
  
    meta = with prev.lib; {
      homepage = "https://gitlab.com/DarkElvenAngel/argononed";
      description = "A replacement daemon for the Argon One Raspberry Pi case";
      license = licenses.mit;
      platforms = platforms.linux;
      maintainers = [ maintainers.misterio77 ];
    };
  };
}
