# ToolHive MCP Server Management
# Runs MCP servers as isolated containers via ToolHive (thv).
# Each server gets a pinned proxy port so mcp.nix can reference stable URLs.
#
# Servers managed by ToolHive:
#   - github              (registry — GitHub API)
#   - memory              (registry — knowledge graph persistence)
#   - sequentialthinking  (registry — structured problem solving)
#   - fetch               (registry — web content fetching)
#   - playwright          (registry — browser automation)
#   - searxng             (custom — SearXNG metasearch via kube cluster)
#   - chat-codex          (custom — GPT-5.5 via any-chat-completions-mcp)
#   - k8s                 (registry — Kubernetes cluster interaction)
#   - context7            (registry — version-specific library docs)
#   - prometheus          (registry — metrics queries)
#   - postgres-mcp-pro    (registry — PostgreSQL operations)
#   - redis               (registry — Redis key-value operations)
#   - grafana             (registry — dashboard management)
#   - hass-mcp            (registry — Home Assistant control)
#
# Servers kept native (need local system access):
#   - ii-desktop     (Hyprland socket, D-Bus)
#   - nixos          (needs /nix/store, flake.lock access)

{ pkgs, config, ... }:

let
  thv = "${pkgs.toolhive}/bin/thv";

  # Pinned proxy ports for stable URLs
  ports = {
    github = 19100;
    memory = 19101;
    sequentialthinking = 19102;
    fetch = 19103;
    searxng = 19104;
    playwright = 19105;
    chat-codex = 19106;
    k8s = 19107;
    context7 = 19108;
    postgres = 19110;
    redis = 19111;
    grafana = 19112;
    hass = 19113;
  };

  # Secret paths from sops-nix
  githubTokenPath = "/run/secrets/github_token";
  openAIKeyPath = "/run/secrets/openai_api_key";
  grafanaTokenPath = "/run/secrets/grafana_service_account_token";

  # Script that ensures all ToolHive MCP servers are running
  startScript = pkgs.writeShellScript "toolhive-mcp-start" ''
    set -euo pipefail
    export PATH="${pkgs.toolhive}/bin:${pkgs.docker}/bin:${pkgs.coreutils}/bin:$PATH"

    # Wait for Docker
    for i in $(seq 1 30); do
      docker info >/dev/null 2>&1 && break
      sleep 1
    done

    # Helper: run a server if not already running
    run_if_needed() {
      local name="$1"; shift
      if thv list 2>/dev/null | grep -q "^$name "; then
        return 0  # already running
      fi
      # Remove stale state if it exists but isn't running
      thv rm "$name" 2>/dev/null || true
      thv run "$@" || echo "WARN: failed to start $name"
    }

    # Read secrets
    GITHUB_TOKEN=""
    OPENAI_KEY=""
    GRAFANA_TOKEN=""
    [ -f "${githubTokenPath}" ] && GITHUB_TOKEN="$(cat ${githubTokenPath})"
    [ -f "${openAIKeyPath}" ] && OPENAI_KEY="$(cat ${openAIKeyPath})"
    [ -f "${grafanaTokenPath}" ] && GRAFANA_TOKEN="$(cat ${grafanaTokenPath})"

    # Register clients (idempotent)
    thv client register kiro 2>/dev/null || true
    thv client register vscode 2>/dev/null || true

    # ── Registry Servers ──────────────────────────────────────────────
    run_if_needed github \
      --name github \
      --proxy-port ${toString ports.github} \
      --transport stdio \
      -e "GITHUB_PERSONAL_ACCESS_TOKEN=$GITHUB_TOKEN" \
      github

    run_if_needed memory \
      --name memory \
      --proxy-port ${toString ports.memory} \
      --transport stdio \
      memory

    run_if_needed sequentialthinking \
      --name sequentialthinking \
      --proxy-port ${toString ports.sequentialthinking} \
      --transport stdio \
      sequentialthinking

    run_if_needed fetch \
      --name fetch \
      --proxy-port ${toString ports.fetch} \
      fetch

    # ── Custom Container Servers ─────────────────────────────────────
    run_if_needed playwright \
      --name playwright \
      --proxy-port ${toString ports.playwright} \
      --transport stdio \
      playwright

    run_if_needed searxng-enhanced \
      --name searxng-enhanced \
      --proxy-port ${toString ports.searxng} \
      --transport stdio \
      --network host \
      --isolate-network=false \
      -e "SEARXNG_ENGINE_API_BASE_URL=http://10.1.1.12:30888/search" \
      -e "DESIRED_TIMEZONE=America/Los_Angeles" \
      ghcr.io/celesrenata/mcp-searxng-enhanced:latest

    # ── Kubernetes ───────────────────────────────────────────────────
    # Container runs as UID 65532 (nonroot), so we need a readable copy
    mkdir -p "${config.home.homeDirectory}/.local/share/toolhive/k8s"
    if [ -f "${config.home.homeDirectory}/.kube/config" ]; then
      cp "${config.home.homeDirectory}/.kube/config" \
         "${config.home.homeDirectory}/.local/share/toolhive/k8s/config"
      chmod 644 "${config.home.homeDirectory}/.local/share/toolhive/k8s/config"
    fi

    run_if_needed k8s \
      --name k8s \
      --proxy-port ${toString ports.k8s} \
      --network host \
      --isolate-network=false \
      -v "${config.home.homeDirectory}/.local/share/toolhive/k8s/config:/home/nonroot/.kube/config:ro" \
      k8s

    # ── Context7 (version-specific docs for any library) ─────────────
    run_if_needed context7 \
      --name context7 \
      --proxy-port ${toString ports.context7} \
      --transport stdio \
      context7

    # ── PostgreSQL ───────────────────────────────────────────────────
    # Uses --target-port 8001 + args to avoid port 8000 conflict with k8s (both on host network)
    run_if_needed postgres \
      --name postgres \
      --proxy-port ${toString ports.postgres} \
      --target-port 8001 \
      --network host \
      --isolate-network=false \
      -v "/etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro" \
      -e "DATABASE_URI=postgresql://celes:PSCh4ng3me!@10.1.1.12:30217/postgres" \
      postgres-mcp-pro -- --transport=sse --sse-port=8001 --sse-host=0.0.0.0

    # ── Redis ────────────────────────────────────────────────────────
    # DISABLED: ghcr.io/stacklok/dockyard/uvx/redis-mcp-server:0.5.0 is broken
    # on Python 3.14 (ModuleNotFoundError: No module named 'mcp.server.fastmcp')
    # Re-enable when upstream fixes the dockyard image.
    # run_if_needed redis \
    #   --name redis \
    #   --proxy-port ${toString ports.redis} \
    #   --transport stdio \
    #   --network host \
    #   -e "REDIS_HOST=10.1.1.12" \
    #   -e "REDIS_PORT=30036" \
    #   redis

    # ── Grafana ──────────────────────────────────────────────────────
    # No --network host: connects to external grafana.celestium.life via egress proxy
    run_if_needed grafana \
      --name grafana \
      --proxy-port ${toString ports.grafana} \
      --session-ttl 2h \
      -v "/etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro" \
      -e "GRAFANA_URL=https://grafana.celestium.life" \
      -e "GRAFANA_SERVICE_ACCOUNT_TOKEN=$GRAFANA_TOKEN" \
      grafana

    # ── Home Assistant ───────────────────────────────────────────────
    run_if_needed hass \
      --name hass \
      --proxy-port ${toString ports.hass} \
      --transport stdio \
      --network host \
      --isolate-network=false \
      -v "/etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro" \
      hass-mcp

    # ── Chat Completions (GPT-5.5/Codex via any-chat-completions-mcp)
    run_if_needed chat-codex \
      --name chat-codex \
      --proxy-port ${toString ports.chat-codex} \
      --transport stdio \
      -e "AI_CHAT_KEY=$OPENAI_KEY" \
      -e "AI_CHAT_NAME=GPT-5.5" \
      -e "AI_CHAT_MODEL=gpt-5.5" \
      -e "AI_CHAT_BASE_URL=https://api.openai.com/v1" \
      -e "AI_CHAT_TIMEOUT=300000" \
      npx://@pyroprompts/any-chat-completions-mcp

    echo "ToolHive MCP servers started."
  '';

in
{
  home.packages = [ pkgs.toolhive ];

  # Systemd user service to start all ToolHive MCP servers at login
  systemd.user.services.toolhive-mcp = {
    Unit = {
      Description = "ToolHive MCP Server Manager";
      After = [ "docker.service" "sops-nix.service" ];
      Wants = [ "docker.service" ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${startScript}";
      Environment = [
        "PATH=${pkgs.toolhive}/bin:${pkgs.docker}/bin:${pkgs.coreutils}/bin:${pkgs.gnugrep}/bin"
        "HOME=${config.home.homeDirectory}"
      ];
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
