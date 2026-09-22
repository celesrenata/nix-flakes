{ lib, pkgs, ... }:
let
  home = "/home/celes";
  omniRouteBaseUrl = "http://127.0.0.1:20128";
  codexAcpVersion = "1.12.0";
  codexAcpRoot = "${home}/.local/share/omniroute-editor";
  codexAcp = "${codexAcpRoot}/node_modules/.bin/codex-acp";
  codexProvider = {
    name = "OmniRoute";
    base_url = "${omniRouteBaseUrl}/v1";
    env_key = "OMNIROUTE_API_KEY";
    wire_api = "responses";
    requires_openai_auth = false;
    stream_idle_timeout_ms = 300000;
  };
  mkCodexConfig = model: contextWindow: builtins.toJSON {
    inherit model;
    model_provider = "omniroute";
    model_context_window = contextWindow;
    model_supports_reasoning_summaries = false;
    model_providers.omniroute = codexProvider;
  };
  mkAirAgent = model: contextWindow: {
    command = codexAcp;
    args = [ ];
    env = {
      OMNIROUTE_API_KEY = "omniroute-local";
      MODEL_PROVIDER = "omniroute";
      CODEX_CONFIG = mkCodexConfig model contextWindow;
      INITIAL_AGENT_MODE = "agent";
      NO_BROWSER = "1";
      APP_SERVER_LOGS = "${home}/.local/state/codex-acp";
    };
  };
  omniCopilotSettings = builtins.toJSON {
    "omnicopilot.baseUrl" = omniRouteBaseUrl;
    "omnicopilot.modelFilter" = "^(local|free|hybrid|cloud)/";
    "omnicopilot.maxOutputTokens" = 16384;
    "omnicopilot.defaultContextLength" = 131072;
    "omnicopilot.exposeToAgentsWindow" = true;
    "chat.agentHost.byokModels.enabled" = true;
  };
  omniRouteTunnel = pkgs.writeShellScript "omniroute-stabulous-tunnel" ''
    exec ${pkgs.openssh}/bin/ssh \
      -NT \
      -o BatchMode=yes \
      -o ExitOnForwardFailure=yes \
      -o ServerAliveInterval=30 \
      -o ServerAliveCountMax=3 \
      -o StrictHostKeyChecking=yes \
      -L 127.0.0.1:20128:127.0.0.1:20128 \
      celes@192.168.42.201
  '';
in
{
  # Keep OmniRoute private on stabulous. Esnixi clients see the router on their
  # own loopback interface through this authenticated, self-healing SSH tunnel.
  systemd.user.services.omniroute-stabulous-tunnel = {
    Unit = {
      Description = "Forward esnixi editor traffic to stabulous OmniRoute";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = omniRouteTunnel;
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };

  home.file.".continue/config.yaml".text = ''
    name: OmniRoute Inference Fabric
    version: 1.0.0
    schema: v1

    models:
      - name: OmniRoute Local Code
        provider: openai
        model: local/code
        apiBase: ${omniRouteBaseUrl}/v1
        apiKey: omniroute-local
        useResponsesApi: false
        contextLength: 16384
        capabilities: [tool_use]
        roles: [chat, edit, apply]

      - name: OmniRoute Hybrid Code
        provider: openai
        model: hybrid/code
        apiBase: ${omniRouteBaseUrl}/v1
        apiKey: omniroute-local
        useResponsesApi: false
        contextLength: 16384
        capabilities: [tool_use]
        roles: [chat, edit, apply]

      - name: OmniRoute Free Code
        provider: openai
        model: free/code
        apiBase: ${omniRouteBaseUrl}/v1
        apiKey: omniroute-local
        useResponsesApi: false
        contextLength: 32768
        capabilities: [tool_use]
        roles: [chat, edit, apply]

      - name: OmniRoute Local Long
        provider: openai
        model: local/long
        apiBase: ${omniRouteBaseUrl}/v1
        apiKey: omniroute-local
        useResponsesApi: false
        contextLength: 131072
        capabilities: [tool_use]
        roles: [chat, edit, apply]

      - name: OmniRoute Cloud Code
        provider: openai
        model: cloud/code
        apiBase: ${omniRouteBaseUrl}/v1
        apiKey: omniroute-local
        useResponsesApi: false
        contextLength: 200000
        capabilities: [tool_use]
        roles: [chat, edit, apply]

      - name: OmniRoute Local Autocomplete
        provider: openai
        model: local/fast
        apiBase: ${omniRouteBaseUrl}/v1
        apiKey: omniroute-local
        useResponsesApi: false
        contextLength: 32768
        roles: [autocomplete]
        autocompleteOptions:
          debounceDelay: 300
          maxPromptTokens: 2048
          onlyMyCode: true
  '';

  home.file.".config/JetBrains/Air/acp.json".text = builtins.toJSON {
    agent_servers = {
      "OmniRoute Local Code" = mkAirAgent "local/code" 16384;
    };
  };

  home.file.".local/share/omniroute-editor/package.json".text = builtins.toJSON {
    name = "esnixi-omniroute-editor-client";
    private = true;
    version = "1.0.0";
    dependencies."@agentclientprotocol/codex-acp" = codexAcpVersion;
  };

  home.activation.omnirouteEditorClients = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    adapter_root="${codexAcpRoot}"
    installed_version="$(${pkgs.nodejs}/bin/node -p \
      "require('$adapter_root/node_modules/@agentclientprotocol/codex-acp/package.json').version" \
      2>/dev/null || true)"
    if [[ "$installed_version" != "${codexAcpVersion}" ]]; then
      $DRY_RUN_CMD ${pkgs.nodejs}/bin/npm install \
        --prefix "$adapter_root" \
        --package-lock=false \
        --ignore-scripts \
        --no-audit \
        --no-fund
    fi

    code_bin="${pkgs.vscode}/bin/code"
    if ! "$code_bin" --list-extensions --show-versions \
      | ${pkgs.gnugrep}/bin/grep -qx 'continue.continue@2.0.0'; then
      $DRY_RUN_CMD "$code_bin" --install-extension continue.continue@2.0.0 --force
    fi

    kiro_bin="/run/current-system/sw/bin/kiro"
    if [[ -x "$kiro_bin" ]] \
      && ! "$kiro_bin" --list-extensions --show-versions \
        | ${pkgs.gnugrep}/bin/grep -qx 'diegosouzapw.omnicopilot@1.3.0'; then
      $DRY_RUN_CMD "$kiro_bin" --install-extension \
        diegosouzapw.omnicopilot --force
    fi

    pycharm_bin="$HOME/.local/share/JetBrains/Toolbox/apps/pycharm-professional/bin/pycharm"
    jetbrains_data="$HOME/.local/share/JetBrains"
    if [[ -x "$pycharm_bin" ]] \
      && ! find "$jetbrains_data" \
        -path '*/PyCharm*/plugins/continue-intellij-extension' \
        -type d -print -quit 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q .; then
      $DRY_RUN_CMD "$pycharm_bin" installPlugins \
        com.github.continuedev.continueintellijextension \
        --give-consent-to-use-third-party-plugins
    fi

    settings_dir="$HOME/.config/Kiro/User"
    settings_file="$settings_dir/settings.json"
    $DRY_RUN_CMD mkdir -p "$settings_dir" "$HOME/.local/state/codex-acp"
    if [[ -f "$settings_file" ]]; then
      settings_source="$settings_file"
    else
      settings_source=${pkgs.writeText "empty-kiro-settings.json" "{}"}
    fi
    $DRY_RUN_CMD ${pkgs.jq}/bin/jq \
      --argjson omni '${omniCopilotSettings}' \
      '. + $omni' \
      "$settings_source" > "$settings_file.omnicopilot-new"
    $DRY_RUN_CMD mv "$settings_file.omnicopilot-new" "$settings_file"
    $DRY_RUN_CMD chmod 600 "$settings_file"
  '';
}
