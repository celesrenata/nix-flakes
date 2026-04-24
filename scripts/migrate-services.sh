#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  migrate-services.sh — Move service data to Fast Pool canonical paths   ║
# ╠═══════════════════════════════════════════════════════════════════════════╣
# ║                                                                         ║
# ║  MIGRATIONS:                                                            ║
# ║    /home/docker       →  /var/lib/docker   (Docker data-root)           ║
# ║    /opt/ollama        →  /var/lib/ollama   (Ollama home + models)       ║
# ║    /opt/vllm          →  /var/lib/vllm     (vLLM home + models)         ║
# ║                                                                         ║
# ║  Edit the SRC variables below if your data lives elsewhere.             ║
# ║                                                                         ║
# ║  SAFETY:                                                                ║
# ║    • Services are stopped before any data is moved                      ║
# ║    • Source data is NEVER deleted — you verify, then remove manually    ║
# ║                                                                         ║
# ║  PREREQUISITES:                                                         ║
# ║    • Fast Pool must be created (run rebuild-storage-layout.sh)          ║
# ║    • Subvolumes must be mounted (nixos-rebuild switch, or --mount)      ║
# ║                                                                         ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
#
# Usage:
#   sudo ./scripts/migrate-services.sh [--dry-run]

set -euo pipefail

# =============================================================================
# MIGRATION CONFIGURATION — edit source paths to match your current layout
# =============================================================================
DOCKER_SRC="/home/docker"
DOCKER_DST="/var/lib/docker"

OLLAMA_SRC="/opt/ollama"
OLLAMA_DST="/var/lib/ollama"

VLLM_SRC="/opt/vllm"
VLLM_DST="/var/lib/vllm"

SERVICES=("docker" "ollama" "vllm")

# =============================================================================
# STATE
# =============================================================================
DRY_RUN=false

# =============================================================================
# LOGGING
# =============================================================================
log()       { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*"; }
log_error() { log "ERROR: $*" >&2; }

run_cmd() {
  if [[ "$DRY_RUN" == true ]]; then
    log "[DRY-RUN] $*"
  else
    log "Running: $*"
    "$@"
  fi
}

check_root() {
  if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root."
    exit 1
  fi
}

check_mount() {
  local path="$1"
  if ! mountpoint -q "$path" 2>/dev/null; then
    if [[ "$DRY_RUN" == false ]]; then
      log_error "$path is not a mountpoint. Is the Fast Pool mounted?"
      log_error "Run 'nixos-rebuild switch' or 'rebuild-storage-layout.sh --mount' first."
      exit 1
    else
      log "[DRY-RUN] Warning: $path is not a mountpoint"
    fi
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) DRY_RUN=true; shift ;;
      -h|--help)
        echo "Usage: $0 [--dry-run]"
        echo ""
        echo "Migrates service data to Fast Pool canonical paths."
        echo "See the header of this script for details."
        exit 0
        ;;
      *) log_error "Unknown argument: $1"; exit 1 ;;
    esac
  done
}

stop_services() {
  log "Stopping services..."
  for svc in "${SERVICES[@]}"; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
      run_cmd systemctl stop "$svc"
      log "  Stopped $svc"
    else
      log "  $svc not running (skipping)"
    fi
  done
}

migrate_path() {
  local src="$1" dst="$2" label="$3"

  if [[ ! -d "$src" ]]; then
    log "  $label: source $src does not exist — skipping"
    return 0
  fi
  if [[ "$src" == "$dst" ]]; then
    log "  $label: source = destination — skipping"
    return 0
  fi

  local src_size
  src_size="$(du -sh "$src" 2>/dev/null | cut -f1)" || src_size="?"
  log "  $label: $src ($src_size) → $dst"
  run_cmd rsync -aHAX --info=progress2 "${src}/" "${dst}/"
  log "  $label: done"
}

main() {
  parse_args "$@"

  log "=== Service Migration ==="
  log ""
  log "  Docker:  $DOCKER_SRC → $DOCKER_DST"
  log "  Ollama:  $OLLAMA_SRC → $OLLAMA_DST"
  log "  vLLM:    $VLLM_SRC → $VLLM_DST"
  log "  Dry run: $DRY_RUN"
  log ""

  if [[ "$DRY_RUN" == false ]]; then
    check_root
  fi

  # Verify targets are mounted
  check_mount "$DOCKER_DST"
  check_mount "$OLLAMA_DST"
  check_mount "$VLLM_DST"

  log "--- Stopping services ---"
  stop_services

  log "--- Migrating data ---"
  migrate_path "$DOCKER_SRC" "$DOCKER_DST" "Docker"
  migrate_path "$OLLAMA_SRC" "$OLLAMA_DST" "Ollama"
  migrate_path "$VLLM_SRC"   "$VLLM_DST"   "vLLM"

  log ""
  log "╔═══════════════════════════════════════════════════════════════════╗"
  log "║  Source data has NOT been deleted.                               ║"
  log "║  Verify everything works before removing old data.              ║"
  log "╚═══════════════════════════════════════════════════════════════════╝"
  log ""
  log "  Verify:"
  log "    nixos-rebuild switch --flake .#esnixi"
  log "    systemctl start docker && docker ps"
  log "    systemctl start ollama && curl localhost:11434/api/tags"
  log ""
  log "  Then remove old data:"
  log "    rm -rf $DOCKER_SRC $OLLAMA_SRC $VLLM_SRC"
}

main "$@"
