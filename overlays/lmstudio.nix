final: prev: {
  lmstudio = final.callPackage ({ appimageTools, fetchurl, lib, graphicsmagick }:
    let
      pname = "lmstudio";
      version = "0.4.6-1";
      src = fetchurl {
        url = "https://installers.lmstudio.ai/linux/x64/${version}/LM-Studio-${version}-x64.AppImage";
        hash = "sha256-FHZ64zmnqHrQyX4ift/lVUzW+HiCVkXpWVa4hkssX/k=";
      };
      appimageContents = appimageTools.extractType2 { inherit pname version src; };
    in
    appimageTools.wrapType2 {
      inherit pname version src;
      
      nativeBuildInputs = [ graphicsmagick ];
      extraPkgs = pkgs: [ pkgs.ocl-icd ];
      
      extraInstallCommands = ''
        mkdir -p $out/share/applications
        src_icon="${appimageContents}/usr/share/icons/hicolor/0x0/apps/lm-studio.png"
        sizes=("16x16" "32x32" "48x48" "64x64" "128x128" "256x256")
        for size in "''${sizes[@]}"; do
          install -dm755 "$out/share/icons/hicolor/$size/apps"
          gm convert "$src_icon" -resize "$size" "$out/share/icons/hicolor/$size/apps/lm-studio.png"
        done
        install -m 444 -D ${appimageContents}/lm-studio.desktop -t $out/share/applications
        mv $out/bin/lmstudio $out/bin/lm-studio
        substituteInPlace $out/share/applications/lm-studio.desktop \
          --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=lm-studio'
        
        # Create lms CLI wrapper that uses steam-run for FHS environment
        mkdir -p $out/bin
        cat > $out/bin/lms << 'WRAPPER'
#!/usr/bin/env bash
# Wait for LM Studio to extract lms binary
if [ ! -f "$HOME/.lmstudio/bin/lms" ]; then
  echo "lms binary not found. Please run lm-studio first to extract it." >&2
  exit 1
fi
exec steam-run "$HOME/.lmstudio/bin/lms" "$@"
WRAPPER
        chmod +x $out/bin/lms
      '';
      
      meta = with lib; {
        description = "LM Studio - local LLM desktop app";
        homepage = "https://lmstudio.ai/";
        license = licenses.unfree;
        mainProgram = "lm-studio";
        platforms = [ "x86_64-linux" ];
        sourceProvenance = with sourceTypes; [ binaryNativeCode ];
      };
    }
  ) {};
}
