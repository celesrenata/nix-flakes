final: prev:
{
  freerdp3Override = prev.freerdp3.overrideAttrs (old: {
      pname = "freerdp";
      version = "3.10.2";
    src = prev.fetchFromGitHub {
      owner = "FreeRDP";
      repo = "FreeRDP";
      rev = "ea2a3ee1b6ee622171669df3814aeca70a496c31";
      sha256 = "sha256-qFr4wINWJvI+4ejVZnjJaw4KMca1xglaJrXH0boHkzs=";
    };
    postPatch =
      ''
        export HOME=$TMP
  
        # skip NIB file generation on darwin
        substituteInPlace "client/Mac/CMakeLists.txt" "client/Mac/cli/CMakeLists.txt" \
          --replace-fail "if(NOT IS_XCODE)" "if (FALSE)"
  
        substituteInPlace "libfreerdp/freerdp.pc.in" \
          --replace-fail "Requires:" "Requires: @WINPR_PKG_CONFIG_FILENAME@"
      ''
      + prev.lib.optionalString (prev.pcsclite != null) ''
        substituteInPlace "winpr/libwinpr/smartcard/smartcard_pcsc.c" \
          --replace-fail "libpcsclite.so" "${prev.lib.getLib prev.pcsclite}/lib/libpcsclite.so"
      '';
  });
}
