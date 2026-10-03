# MCP (Model Context Protocol) Server Configuration
# Generates ~/.kiro/settings/mcp.json and Zoo Code MCP settings declaratively.
#
# Architecture:
#   - ToolHive-managed servers: referenced by URL (container-isolated, see toolhive.nix)
#   - Native servers: referenced by command (need local system access)
{ inputs, lib, pkgs, config, ... }:

let
  # ── ToolHive Proxy Ports (must match toolhive.nix) ────────────────────────
  thvPort = name: {
    github = 19100;
    memory = 19101;
    sequentialthinking = 19102;
    fetch = 19103;
    searxng-enhanced = 19104;
    playwright = 19105;
    chat-codex = 19106;
    k8s = 19107;
    context7 = 19108;
    postgres = 19110;
    redis = 19111;
    grafana = 19112;
    hass = 19113;
  }.${name};

  thvUrl = name: "http://localhost:${toString (thvPort name)}/mcp";
  thvSseUrl = name: "http://localhost:${toString (thvPort name)}/sse";
  omniRouteMcpUrl = "https://omniroute.celestium.life/api/mcp/stream";

  # ── MCP Client Configuration ─────────────────────────────────────────────
  mcpConfig = {
    mcpServers = {
      # OmniRoute's own scoped observability tools on the public gateway.
      omniroute-observability = {
        url = omniRouteMcpUrl;
      };

      # A single MCP call fans out independent inference work across GPUs.
      omniroute-workers = {
        command = "${pkgs.python3}/bin/python3";
        args = [ "${config.home.homeDirectory}/.local/share/omniroute-workers/server.py" ];
        env.OMNIROUTE_BASE_URL = "https://omniroute.celestium.life/v1";
        autoApprove = [ "start_parallel_tasks" "get_parallel_tasks" "cancel_parallel_tasks" "list_zoo_chats" ];
      };

      # ── ToolHive-managed (container-isolated) ──────────────────────────
      github = {
        url = thvUrl "github";
        autoApprove = [ "get_file_contents" ];
      };

      memory = {
        url = thvUrl "memory";
      };

      sequential-thinking = {
        url = thvUrl "sequentialthinking";
        autoApprove = [ "sequentialthinking" ];
      };

      fetch = {
        url = thvUrl "fetch";
      };

      playwright = {
        url = thvUrl "playwright";
        autoApprove = [
          "browser_navigate" "browser_console_messages" "browser_network_requests"
          "browser_snapshot" "browser_run_code_unsafe" "browser_network_request"
          "browser_click" "browser_close" "browser_resize" "browser_evaluate"
          "browser_wait_for" "browser_tabs" "browser_fill_form" "browser_type"
          "browser_select_option" "browser_take_screenshot"
        ];
      };

      searxng-enhanced = {
        url = thvUrl "searxng-enhanced";
        autoApprove = [ "search_web" "get_website" "get_current_datetime" ];
      };

      chat-codex = {
        url = thvUrl "chat-codex";
        autoApprove = [ "chat-with-gpt-5.5" ];
      };

      k8s = {
        url = thvUrl "k8s";
      };

      context7 = {
        url = thvUrl "context7";
        autoApprove = [ "resolve-library-id" "get-library-docs" "query-docs" ];
      };

      postgres = {
        url = thvSseUrl "postgres";
        transport = "sse";
      };

      redis = {
        url = thvUrl "redis";
        autoApprove = [ "get" "keys" "info" ];
      };

      grafana = {
        url = thvSseUrl "grafana";
        transport = "sse";
        autoApprove = [ "search_dashboards" "list_datasources" ];
      };

      hass = {
        url = thvUrl "hass";
      };

      # ── Native servers (need local system access) ──────────────────────
      nixos = {
        command = lib.getExe pkgs.mcp-nixos;
        args = [ ];
        env = { };
        autoApprove = [
          "nixos_search" "nixos_info" "nixos_stats"
          "home_manager_search" "home_manager_info" "home_manager_stats"
          "nix_packages_search" "nix_packages_info" "nix_packages_stats"
        ];
      };

      ii-desktop = {
        command = lib.getExe pkgs.ii-desktop-mcp;
        args = [ ];
        env = {
          HYPRLAND_INSTANCE_SIGNATURE = "$(hyprctl instances -j | jq -r '.[0].instance')";
        };
        autoApprove = [
          "config_read" "audio_status" "network_status" "network_wifi_list"
          "systemd_status" "systemd_logs" "clipboard_list" "apps_search"
          "diagnostic_bundle" "shell_logs" "system_info" "list_monitors"
          "list_workspaces" "list_clients" "get_active_window" "screenshot"
          "describe_image" "describe_images"
        ];
      };
    };
  };

  # ── Kiro Agent Configuration ─────────────────────────────────────────────
  kiroDefaultAgent = {
    name = "kiro_default";
    description = "Default Kiro CLI agent with full MCP tool access";
    tools = [ "*" ];
    allowedTools = [ ];
    useLegacyMcpJson = true;
  };

  # ── ZooCode/VSCode MCP Configuration ────────────────────────────────────
  # ZooCode supports: "streamable-http", "sse", or "stdio" (implicit for command-based)
  zooCodeMcpConfig = {
    mcpServers = builtins.mapAttrs (name: server:
      (if server ? url then {
        url = server.url;
        type = server.transport or "streamable-http";
      } else {
        command = server.command;
        args = server.args or [ ];
        env = server.env or { };
      })
      // (if server ? autoApprove then { alwaysAllow = server.autoApprove; } else { })
      // (if server ? timeout then { timeout = server.timeout / 1000; } else { })
    ) mcpConfig.mcpServers;
  };

  # ── VSCode Native MCP Configuration ────────────────────────────────────
  # Format: { "servers": { name: { "url": "...", "type": "http"|"sse" } | { "command": "...", "args": [...] } } }
  vscodeMcpConfig = {
    servers = builtins.mapAttrs (name: server:
      if server ? url then {
        url = server.url;
        type = server.transport or "http";
      } else {
        command = server.command;
        args = server.args or [ ];
      }
    ) mcpConfig.mcpServers;
  };

in
{
  imports = [ ./zoo-parallel.nix ];
  home.file.".local/share/omniroute-workers/server.py".source = ./omniroute-workers.py;
  home.file.".roo/rules/30-omniroute-parallel.md".source = ./omniroute-parallel.md;
  home.packages = [ (pkgs.writeShellScriptBin "omniroute-apply-routing" ''
    exec ${pkgs.python3}/bin/python3 ${./omniroute-routing.py} "$@"
  '') ];

  # Seed ~/.kiro/settings/mcp.json only if it doesn't exist (user/Kiro manages it at runtime)
  # Also removes duplicate 'sequentialthinking' that Kiro auto-discovers from ToolHive
  home.activation.seedKiroMcp = let
    mcpJsonFile = pkgs.writeText "mcp.json" (builtins.toJSON mcpConfig);
  in lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ ! -f "$HOME/.kiro/settings/mcp.json" ]; then
      mkdir -p "$HOME/.kiro/settings"
      cp ${mcpJsonFile} "$HOME/.kiro/settings/mcp.json"
      chmod 644 "$HOME/.kiro/settings/mcp.json"
    fi
    # Remove duplicate sequentialthinking (Kiro auto-adds it; we define sequential-thinking)
    if [ -f "$HOME/.kiro/settings/mcp.json" ] && ${pkgs.jq}/bin/jq -e '.mcpServers.sequentialthinking' "$HOME/.kiro/settings/mcp.json" &>/dev/null; then
      ${pkgs.jq}/bin/jq 'del(.mcpServers.sequentialthinking)' "$HOME/.kiro/settings/mcp.json" > "$HOME/.kiro/settings/mcp.json.tmp" \
        && mv "$HOME/.kiro/settings/mcp.json.tmp" "$HOME/.kiro/settings/mcp.json"
    fi
  '';

  home.file.".kiro/agents/kiro_default.json" = {
    text = builtins.toJSON kiroDefaultAgent;
  };

  # Quickshell's own MCP config — written fresh on every rebuild, never touched by Kiro
  home.file.".local/share/quickshell/mcp.json" = {
    text = builtins.toJSON mcpConfig;
  };

  # ZooCode MCP settings (VS Code extension)
  # Seed Zoo Code MCP settings only if missing
  home.activation.seedZooCodeMcp = let
    zooJson = pkgs.writeText "mcp_settings.json" (builtins.toJSON zooCodeMcpConfig);
  in lib.hm.dag.entryAfter ["writeBoundary"] ''
    target="$HOME/.config/Code/User/globalStorage/zoocodeorganization.zoo-code/settings/mcp_settings.json"
    if [ ! -f "$target" ]; then
      mkdir -p "$(dirname "$target")"
      cp ${zooJson} "$target"
      chmod 644 "$target"
    fi
  '';

  # Seed VS Code native MCP only if missing
  # Also removes duplicate sequentialthinking on existing files
  home.activation.seedVscodeMcp = let
    vscodeJson = pkgs.writeText "mcp.json" (builtins.toJSON vscodeMcpConfig);
  in lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ ! -f "$HOME/.config/Code/User/mcp.json" ]; then
      mkdir -p "$HOME/.config/Code/User"
      cp ${vscodeJson} "$HOME/.config/Code/User/mcp.json"
      chmod 644 "$HOME/.config/Code/User/mcp.json"
    fi
    # Remove duplicate sequentialthinking from VS Code config
    if [ -f "$HOME/.config/Code/User/mcp.json" ] && ${pkgs.jq}/bin/jq -e '.servers.sequentialthinking' "$HOME/.config/Code/User/mcp.json" &>/dev/null; then
      ${pkgs.jq}/bin/jq 'del(.servers.sequentialthinking)' "$HOME/.config/Code/User/mcp.json" > "$HOME/.config/Code/User/mcp.json.tmp" \
        && mv "$HOME/.config/Code/User/mcp.json.tmp" "$HOME/.config/Code/User/mcp.json"
    fi
  '';

  # Seed ~/ai/mcp.json only if missing
  home.activation.seedAiMcp = let
    aiJson = pkgs.writeText "ai-mcp.json" (builtins.toJSON mcpConfig);
  in lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ ! -f "$HOME/ai/mcp.json" ]; then
      mkdir -p "$HOME/ai"
      cp ${aiJson} "$HOME/ai/mcp.json"
      chmod 644 "$HOME/ai/mcp.json"
    fi
  '';

  # Add newly declared servers to existing client profiles without replacing
  # per-client changes. VS Code Remote-SSH uses a separate server-side profile.
  home.activation.syncMcpProfiles = let
    kiroJson = pkgs.writeText "kiro-mcp.json" (builtins.toJSON mcpConfig);
    zooJson = pkgs.writeText "zoo-mcp_settings.json" (builtins.toJSON zooCodeMcpConfig);
    vscodeJson = pkgs.writeText "vscode-mcp.json" (builtins.toJSON vscodeMcpConfig);
  in lib.hm.dag.entryAfter [ "writeBoundary" "seedKiroMcp" "seedZooCodeMcp" "seedVscodeMcp" ] ''
    sync_mcp_file() {
      desired="$1"
      target="$2"
      section="$3"
      ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$target")"
      if [ ! -f "$target" ]; then
        ${pkgs.coreutils}/bin/cp "$desired" "$target"
      else
        ${pkgs.jq}/bin/jq --slurpfile defaults "$desired" --arg section "$section" \
          '.[$section] = (($defaults[0][$section] // {}) + (.[$section] // {}))' \
          "$target" > "$target.omniroute-new"
        if ! ${pkgs.diffutils}/bin/cmp -s "$target" "$target.omniroute-new"; then
          ${pkgs.coreutils}/bin/mv "$target.omniroute-new" "$target"
        else
          ${pkgs.coreutils}/bin/rm "$target.omniroute-new"
        fi
      fi
    }

    sync_mcp_file ${kiroJson} "$HOME/.kiro/settings/mcp.json" mcpServers
    sync_mcp_file ${zooJson} "$HOME/.config/Code/User/globalStorage/zoocodeorganization.zoo-code/settings/mcp_settings.json" mcpServers
    sync_mcp_file ${zooJson} "$HOME/.vscode-server/data/User/globalStorage/zoocodeorganization.zoo-code/settings/mcp_settings.json" mcpServers
    sync_mcp_file ${vscodeJson} "$HOME/.config/Code/User/mcp.json" servers
    sync_mcp_file ${vscodeJson} "$HOME/.vscode-server/data/User/mcp.json" servers

    # Endpoint migrations are authoritative for the two OmniRoute entries;
    # preserve every unrelated per-client customization.
    sync_omniroute_endpoints() {
      desired="$1"
      target="$2"
      section="$3"
      [ -f "$target" ] || return 0
      ${pkgs.jq}/bin/jq --slurpfile defaults "$desired" --arg section "$section" \
        '.[$section]["omniroute-observability"] = $defaults[0][$section]["omniroute-observability"]
         | .[$section]["omniroute-workers"] = $defaults[0][$section]["omniroute-workers"]' \
        "$target" > "$target.omniroute-endpoints"
      ${pkgs.coreutils}/bin/mv "$target.omniroute-endpoints" "$target"
    }

    sync_omniroute_endpoints ${kiroJson} "$HOME/.kiro/settings/mcp.json" mcpServers
    sync_omniroute_endpoints ${zooJson} "$HOME/.config/Code/User/globalStorage/zoocodeorganization.zoo-code/settings/mcp_settings.json" mcpServers
    sync_omniroute_endpoints ${zooJson} "$HOME/.vscode-server/data/User/globalStorage/zoocodeorganization.zoo-code/settings/mcp_settings.json" mcpServers
    sync_omniroute_endpoints ${vscodeJson} "$HOME/.config/Code/User/mcp.json" servers
    sync_omniroute_endpoints ${vscodeJson} "$HOME/.vscode-server/data/User/mcp.json" servers
  '';
}
