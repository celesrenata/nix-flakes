final: prev:
rec {
  t2fanrd = prev.rustPlatform.buildRustPackage rec {
    pname = "t2fanrd";
    version = "0.9.0";

    src = prev.fetchFromGitHub {
      owner = "GnomedDev";
      repo = "T2FanRD";
      rev = "85027878e4d7fa0170fea1213d6f8dd972d60e83";
      sha256 = "sha256-vOJAYbB/ZcRxM+/lrkab/PcON3vOz3o6eqPvM9hmaOw=";
    };

    cargoHash = "sha256-oB0zuTvCuFR5edTrUnZMVuNQa+mwl15Tjnxm4+FNoFk=";


    installPhase = ''
      ls -R
      install -m755 -D target/x86_64-unknown-linux-gnu/release/t2fanrd $out/bin/t2fanrd
    '';
  };
}