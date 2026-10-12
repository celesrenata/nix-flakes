# Shared VS Code and custom Zoo parallel-tools configuration.
{ config, lib, pkgs, ... }:

let
  zooParallel = pkgs.vscode-utils.buildVscodeExtension {
    pname = "zoo-code-parallel";
    version = "3.84.2";
    src = ../../packages/vscode-extensions/zoo-code-3.84.2-parallel.vsix;
    vscodeExtPublisher = "ZooCodeOrganization";
    vscodeExtName = "zoo-code";
    vscodeExtUniqueId = "ZooCodeOrganization.zoo-code";
  };

  # Electron's setuid sandbox cannot be installed from an unprivileged Nix
  # profile on generic Linux. XRDP is also more reliable with software GL.
  vscodePackage = if config.targets.genericLinux.enable then
    pkgs.symlinkJoin {
      name = "vscode-generic-linux";
      paths = [ pkgs.vscode ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      meta.mainProgram = "code";
      postBuild = ''
        wrapProgram "$out/bin/code" \
          --add-flags "--no-sandbox" \
          --add-flags "--disable-gpu"
      '';
    }
  else
    pkgs.vscode;
in
{
  programs.vscode = {
    enable = true;
    package = vscodePackage;

    # Keep the directory mutable for extensions not yet represented in Nix,
    # while ensuring the custom Zoo derivation is restored on every switch.
    mutableExtensionsDir = true;
    profiles.default = {
      extensions = (with pkgs.vscode-extensions; [
        eamodio.gitlens
        jnoortheen.nix-ide
        oderwat.indent-rainbow
      ]) ++ [ zooParallel ];

      userSettings = {
        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "nixd";
        "nix.formatterPath" = "nixfmt";
        "python.defaultInterpreterPath" = "${config.home.homeDirectory}/.nix-profile/bin/python3";
        "zoo-code.autoImportSettingsPath" =
          "${config.home.homeDirectory}/.config/Code/User/omniroute-zoo-profiles.json";
        "workbench.editor.enablePreview" = false;
      };
    };
  };

  home.packages = [ pkgs.noto-fonts-color-emoji ];

  # The import file may contain provider credentials, so it deliberately stays
  # outside the Nix store. Enforce only the non-secret experiment flags in place.
  home.activation.zooParallelTools = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings="$HOME/.config/Code/User/omniroute-zoo-profiles.json"
    if [ -f "$settings" ]; then
      tmp="$(${pkgs.coreutils}/bin/mktemp)"
      ${pkgs.jq}/bin/jq '
        .globalSettings = (.globalSettings // {}) |
        .globalSettings.experiments = ((.globalSettings.experiments // {}) + {
          parallelTasks: true,
          parallelToolExecution: true,
          runSlashCommand: true
        })
      ' "$settings" > "$tmp"
      ${pkgs.coreutils}/bin/chmod 600 "$tmp"
      ${pkgs.coreutils}/bin/mv "$tmp" "$settings"
    fi
  '';
}
