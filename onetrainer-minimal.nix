{
  description = "OneTrainer - Minimal flake for diffusion model training";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      
      python = pkgs.python311;
      
      pythonEnv = python.withPackages (ps: with ps; [
        pip
        torch-bin
        torchvision-bin
        numpy
        pillow
        tqdm
        pyyaml
        tkinter
        psutil
        requests
      ]);
      
    in {
      packages.${system} = {
        default = self.packages.${system}.onetrainer;
        
        onetrainer = pkgs.stdenv.mkDerivation {
          pname = "onetrainer";
          version = "unstable";
          
          src = ~/sources/OneTrainer;
          
          nativeBuildInputs = [ pkgs.makeWrapper ];
          buildInputs = [ pythonEnv pkgs.cudatoolkit pkgs.libGL pkgs.gtk3 ];
          
          installPhase = ''
            mkdir -p $out/{bin,share/onetrainer}
            cp -r . $out/share/onetrainer/
            
            makeWrapper ${pythonEnv}/bin/python $out/bin/onetrainer-ui \
              --add-flags "$out/share/onetrainer/scripts/train_ui.py" \
              --set PYTHONPATH "$out/share/onetrainer" \
              --set HF_HUB_DISABLE_XET "1" \
              --chdir "$out/share/onetrainer"
          '';
        };
      };
      
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [ pythonEnv pkgs.cudatoolkit pkgs.libGL pkgs.gtk3 ];
        shellHook = ''
          export HF_HUB_DISABLE_XET=1
          echo "OneTrainer development environment"
        '';
      };
    };
}
