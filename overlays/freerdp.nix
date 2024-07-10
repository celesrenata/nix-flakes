final: prev:
{
  freerdp3Override = prev.freerdp3.overrideAttrs (old: {
      pname = "freerdp";
      version = "3.6.2";
    src = prev.fetchFromGitHub {
      owner = "FreeRDP";
      repo = "FreeRDP";
      rev = "2631f8d080ce80898c49464b78f8ab2f08e858aa";
      sha256 = "sha256-HD5Ic8Mqo/aDKAj0heuwMjapjhyRBp0Bq8oYoqhhKB4=";
    };
  });
}
