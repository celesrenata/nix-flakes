(self: super: {
      cudaPackages = super.cudaPackages // {
        tensorrt = super.cudaPackages.tensorrt_10_9.overrideAttrs
          (oldAttrs: rec {
            dontCheckForBrokenSymlinks = true;
            outputs = [ "out" ];
            fixupPhase = ''
              ${
                oldAttrs.fixupPhase or ""
              } # Remove broken symlinks in the main output
               find $out -type l ! -exec test -e \{} \; -delete || true'';
          });
      };
    })

