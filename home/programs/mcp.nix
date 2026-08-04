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

  # ── MCP Client Configuration ─────────────────────────────────────────────
  mcpConfig = {
    mcpServers = {
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
        autoApprove = [ "resolve-library-id" "get-library-docs" ];
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
        command = lib.getExe inputs.ii-desktop-mcp.packages.${pkgs.system}.default;
        args = [ ];
        env = {
          HYPRLAND_INSTANCE_SIGNATURE = "$(hyprctl instances -j | jq -r '.[0].instance')";
        };
        autoApprove = [
          "config_read" "audio_status" "network_status" "network_wifi_list"
          "systemd_status" "systemd_logs" "clipboard_list" "apps_search"
          "diagnostic_bundle" "shell_logs" "system_info" "list_monitors"
          "list_workspaces" "list_clients" "get_active_window" "screenshot"
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
}
