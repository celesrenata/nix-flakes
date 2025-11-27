final: prev:
let
  nocaps = false;
in
{
  freerdp3Override = prev.freerdp.overrideAttrs (old: {
    pname = "freerdp";
    version = "3.15.0";
    src = prev.fetchFromGitHub {
      owner = "FreeRDP";
      repo = "FreeRDP";
      rev = "0ce68ddd1cd6ed067392a17d9858c739f2bf37ec";
      sha256 = "sha256-xz1vP58hElXe/jLVrJOSpXcbqShBV7LHRpzqPLa2fDU=";
    };

    # Disable patching that doesn't apply anymore
    postPatch = ''
      export HOME=$TMP

      # skip NIB file generation on darwin
      substituteInPlace "libfreerdp/freerdp.pc.in" \
        --replace-fail "Requires:" "Requires: @WINPR_PKG_CONFIG_FILENAME@"

      substituteInPlace client/SDL/SDL2/dialogs/{sdl_input.cpp,sdl_select.cpp,sdl_widget.cpp,sdl_widget.hpp} \
        --replace-fail "<SDL_ttf.h>" "<SDL2/SDL_ttf.h>"
    ''
    + prev.lib.optionalString (prev.pcsclite != null) ''
      substituteInPlace "winpr/libwinpr/smartcard/smartcard_pcsc.c" \
        --replace-fail "libpcsclite.so" "${prev.lib.getLib prev.pcsclite}/lib/libpcsclite.so"
    ''
    + prev.lib.optionalString nocaps ''
      substituteInPlace "libfreerdp/locale/keyboard_xkbfile.c" \
        --replace-fail "RDP_SCANCODE_CAPSLOCK" "RDP_SCANCODE_LCONTROL"
    '';
  });
}

