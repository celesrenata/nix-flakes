{ lib, pkgs, config, ... }:
let
  root = "${config.home.homeDirectory}/.local/share/omniroute-editor";
  phases = [ "constitution" "specify" "clarify" "plan" "tasks" "analyze" "checklist" "implement" "converge" ];
in {
  home.file = {
    # Routine generated-file writes may use a shell variable for a temporary path.
    # Keep all other DCG rules, including sensitive-path truncation, at their defaults.
    ".config/dcg/config.toml" = {
      text = ''
        [policy.rules]
        "core.filesystem:redirect-truncate-dynamic-path" = "warn"
      '';
      force = true;
    };
    ".local/share/omniroute-editor/zoo-spec-mode.json".source = ./zoo-spec-mode.json;
    ".local/share/omniroute-editor/zoo-project-reader-mode.json".source = ./zoo-project-reader-mode.json;
    ".local/share/omniroute-editor/zoo-project-research-mode.json".source = ./zoo-project-research-mode.json;
    ".local/share/omniroute-editor/zoo-spec-setup.py".source = ./zoo-spec-setup.py;
    ".roo/commands/force-parallel.md".source = ./zoo-force-parallel.md;
    ".local/share/omniroute-workers/zoo_chats.py".source = ./zoo-chats.py;
    ".local/share/omniroute-editor/omniroute-mode.py".source = ./omniroute-mode.py;
    ".codex/skills/omniroute-routing-mode/SKILL.md" = {
      source = ./omniroute-routing-mode.SKILL.md;
      force = true;
    };
    ".codex/skills/omniroute-routing-mode/scripts/omniroute-mode.py" = {
      source = ./omniroute-mode.py;
      force = true;
    };
    ".roo/skills/omniroute-routing-mode/SKILL.md" = {
      source = ./omniroute-routing-mode.SKILL.md;
      force = true;
    };
    ".roo/skills/omniroute-routing-mode/scripts/omniroute-mode.py" = {
      source = ./omniroute-mode.py;
      force = true;
    };
  } // builtins.listToAttrs (map (phase: {
    name = ".roo/commands/speckit-${phase}.md";
    value.text = ''
      ---
      description: Run the installed Spec Kit ${phase} workflow with Zoo task tracking
      mode: spec-orchestrator
      ---
      Read the current repository's .clinerules/workflows/speckit-${phase}.md
      and carry out that installed workflow with the user's arguments. If absent,
      inspect .specify/workflows and use the matching installed workflow; report
      missing setup instead of silently installing or resetting Spec Kit.
      Preserve the user's authorization and changes. Mirror stable task IDs and the
      spec path into update_todo_list. Use parallel_tasks only for independent ready
      scopes with separate file ownership, then review and integrate all results.
      Commands that publish issues or communicate externally require explicit user intent.
    '';
  }) phases);
  home.packages = [ (pkgs.writeShellScriptBin "omniroute-mode" ''
    exec ${pkgs.python3}/bin/python3 ${root}/omniroute-mode.py "$@"
  '') ];
  home.activation.zooNativeParallel = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    $DRY_RUN_CMD ${pkgs.python3}/bin/python3 ${root}/zoo-spec-setup.py \
      "$HOME/.config/Code/User/omniroute-zoo-profiles.json" ${root}/zoo-spec-mode.json ${root}/zoo-project-reader-mode.json ${root}/zoo-project-research-mode.json
  '';
}
