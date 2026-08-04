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
        url = thvUrl "postgres";
      };

      redis = {
        url = thvUrl "redis";
        autoApprove = [ "get" "keys" "info" ];
      };

      grafana = {
        url = thvUrl "grafana";
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
  zooCodeMcpConfig = {
    mcpServers = builtins.mapAttrs (name: server:
      (if server ? url then { url = server.url; } else {
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
        type = "http";
      } else {
        command = server.command;
        args = server.args or [ ];
      }
    ) mcpConfig.mcpServers;
  };

in
{
  # Seed ~/.kiro/settings/mcp.json only if it doesn't exist (user/Kiro manages it at runtime)
  home.activation.seedKiroMcp = let
    mcpJsonFile = pkgs.writeText "mcp.json" (builtins.toJSON mcpConfig);
  in lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ ! -f "$HOME/.kiro/settings/mcp.json" ]; then
      mkdir -p "$HOME/.kiro/settings"
      cp ${mcpJsonFile} "$HOME/.kiro/settings/mcp.json"
      chmod 644 "$HOME/.kiro/settings/mcp.json"
    fi
  '';

  home.file.".kiro/agents/kiro_default.json" = {
    text = builtins.toJSON kiroDefaultAgent;
  };

  # ZooCode MCP settings (VS Code extension)
  xdg.configFile."Code/User/globalStorage/zoocodeorganization.zoo-code/settings/mcp_settings.json" = {
    text = builtins.toJSON zooCodeMcpConfig;
  };

  # VSCode native MCP (Copilot/built-in MCP support)
  xdg.configFile."Code/User/mcp.json" = {
    text = builtins.toJSON vscodeMcpConfig;
  };

  # ~/ai/mcp.json — generic MCP config for quickshell sidebar and other tools
  home.file."ai/mcp.json" = {
    text = builtins.toJSON mcpConfig;
  };
}
