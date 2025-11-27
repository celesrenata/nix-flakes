{
  description = "OneTrainer - A comprehensive tool for training diffusion models";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            cudaSupport = true;
          };
        };

        python = pkgs.python311;
        
        pythonEnv = python.withPackages (ps: with ps; [
          # Build essentials
          pip
          setuptools
          wheel
          
          # Base requirements
          numpy
          opencv4
          pillow
          tqdm
          pyyaml
          scipy
          matplotlib
          
          # PyTorch ecosystem
          torch-bin
          torchvision-bin
          
          # ML/AI libraries
          accelerate
          safetensors
          tensorboard
          transformers
          sentencepiece
          
          # UI components
          tkinter
          
          # Utilities
          psutil
          requests
        ]);

      in
      {
        packages = {
          default = self.packages.${system}.onetrainer;
          
          onetrainer = pkgs.stdenv.mkDerivation rec {
            pname = "onetrainer";
            version = "2024-01-07";
            
            src = pkgs.fetchFromGitHub {
              owner = "Nerogar";
              repo = "OneTrainer";
              rev = "ccc050125c65f533a4df5312ed531cb340f10b09";
              sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
            };
            
            nativeBuildInputs = with pkgs; [
              pythonEnv
              git
              makeWrapper
            ];
            
            buildInputs = with pkgs; [
              # System libraries
              xorg.libX11
              xorg.libXext
              xorg.libXrender
              xorg.libXtst
              libGL
              libGLU
              glib
              gtk3
              cairo
              pango
              gdk-pixbuf
              
              # CUDA support
              cudatoolkit
              cudnn
              linuxPackages.nvidia_x11
              
              # Media processing
              ffmpeg
              
              # System dependencies
              zlib
              stdenv.cc.cc.lib
              openssl
              libffi
              ncurses
            ];
            
            dontBuild = true;
            
            installPhase = ''
              runHook preInstall
              
              mkdir -p $out/{bin,lib/onetrainer}
              cp -r . $out/lib/onetrainer/
              
              # Install Python dependencies
              export HOME=$TMPDIR
              cd $out/lib/onetrainer
              
              ${pythonEnv}/bin/python -m venv venv
              source venv/bin/activate
              pip install --no-cache-dir -r requirements-global.txt
              pip install --no-cache-dir -r requirements-cuda.txt
              
              # Create wrapper scripts
              makeWrapper ${pythonEnv}/bin/python $out/bin/onetrainer-ui \
                --add-flags "$out/lib/onetrainer/scripts/train_ui.py" \
                --set PYTHONPATH "$out/lib/onetrainer:$out/lib/onetrainer/venv/lib/python3.11/site-packages" \
                --set HF_HUB_DISABLE_XET "1" \
                --set CUDA_PATH "${pkgs.cudatoolkit}" \
                --set LD_LIBRARY_PATH "${pkgs.lib.makeLibraryPath buildInputs}" \
                --chdir "$out/lib/onetrainer"
              
              makeWrapper ${pythonEnv}/bin/python $out/bin/onetrainer-cli \
                --add-flags "$out/lib/onetrainer/scripts/train.py" \
                --set PYTHONPATH "$out/lib/onetrainer:$out/lib/onetrainer/venv/lib/python3.11/site-packages" \
                --set HF_HUB_DISABLE_XET "1" \
                --set CUDA_PATH "${pkgs.cudatoolkit}" \
                --set LD_LIBRARY_PATH "${pkgs.lib.makeLibraryPath buildInputs}" \
                --chdir "$out/lib/onetrainer"
              
              runHook postInstall
            '';
            
            meta = with pkgs.lib; {
              description = "A comprehensive tool for training diffusion models";
              homepage = "https://github.com/Nerogar/OneTrainer";
              license = licenses.asl20;
              platforms = platforms.linux;
            };
          };
        };
        
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            pythonEnv
            git
            cudatoolkit
            cudnn
            xorg.libX11
            libGL
            gtk3
            ruff
            black
          ];
          
          shellHook = ''
            export CUDA_PATH=${pkgs.cudatoolkit}
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath (with pkgs; [ cudatoolkit cudnn linuxPackages.nvidia_x11 libGL ])}"
            export HF_HUB_DISABLE_XET=1
            
            echo "OneTrainer development environment loaded"
            echo "CUDA Path: $CUDA_PATH"
          '';
        };
        
        apps = {
          default = self.apps.${system}.onetrainer-ui;
          
          onetrainer-ui = flake-utils.lib.mkApp {
            drv = self.packages.${system}.onetrainer;
            exePath = "/bin/onetrainer-ui";
          };
          
          onetrainer-cli = flake-utils.lib.mkApp {
            drv = self.packages.${system}.onetrainer;
            exePath = "/bin/onetrainer-cli";
          };
        };
      });
}
