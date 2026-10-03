# esnixi backup → Synology NFS
#
# Backs up the *valuable, non-reproducible* state of esnixi to the Synology NAS
# at 192.168.42.8:/volume1/Backups. Reproducible state (/nix), scratch
# (/var/tmp, /mnt/fast), containers (/var/lib/docker), AI models and games are
# NOT part of the default backup.
#
#   Default set  → esnixi-YYYYMMDD        (system + home + persist)
#   --games      → esnixi-games-YYYYMMDD  (/mnt/games only)
#   --ai         → esnixi-ai-YYYYMMDD     (ollama + vLLM models only)
#
# The script (`esnixi-backup`) is on PATH after a rebuild. A weekly systemd
# timer runs the default (non-model, non-game) backup automatically.
#
# WHY rsync-over-NFS and not btrfs send: the target is a Synology (ext4/btrfs
# but exported as plain NFS, no btrfs-receive), so a snapshot + rsync gives an
# atomic, consistent, browsable tree the NAS can serve directly. Snapshots are
# taken on the source btrfs pools first so the copy is point-in-time coherent.

{ config, lib, pkgs, ... }:

let
  nfsHost = "192.168.42.8";
  nfsExport = "/volume1/Backups";

  # System-pool subvolumes worth preserving (raid1 mirror). /nix is reproducible
  # and deliberately excluded; the flake source lives under /home so it is
  # captured by the @home backup.
  #
  # Fast-pool AI-model and game subvolumes are handled by the --ai / --games
  # switches only. /var/lib/docker, /var/tmp, /mnt/fast are regenerable scratch
  # and are never backed up.

  esnixiBackup = pkgs.writeShellApplication {
    name = "esnixi-backup";
    runtimeInputs = with pkgs; [ rsync util-linux coreutils btrfs-progs gnugrep gawk ];
    text = ''
      # esnixi-backup [--ai] [--games] [--dry-run]
      #
      # No flag        → system + home + persist   → esnixi-<date>
      # --games        → /mnt/games                → esnixi-games-<date>
      # --ai           → ollama + vllm models       → esnixi-ai-<date>
      # (--ai and --games may be combined with the default and with each other)

      set -euo pipefail

      NFS_HOST="${nfsHost}"
      NFS_EXPORT="${nfsExport}"
      DATE="$(date +%Y%m%d)"

      DO_DEFAULT=1
      DO_GAMES=0
      DO_AI=0
      DRY=""

      # If the user asks *only* for --ai/--games, don't also run the default set.
      EXPLICIT=0
      for arg in "$@"; do
        case "$arg" in
          --games) DO_GAMES=1; EXPLICIT=1 ;;
          --ai)    DO_AI=1;    EXPLICIT=1 ;;
          --all)   DO_GAMES=1; DO_AI=1 ;;    # default + games + ai
          --dry-run) DRY="--dry-run" ;;
          -h|--help)
            echo "usage: esnixi-backup [--ai] [--games] [--all] [--dry-run]"
            echo "  (no flag)  system + home + persist  -> esnixi-$DATE"
            echo "  --games    /mnt/games               -> esnixi-games-$DATE"
            echo "  --ai       ollama + vllm models      -> esnixi-ai-$DATE"
            echo "  --all      default + games + ai"
            exit 0 ;;
          *) echo "unknown arg: $arg" >&2; exit 2 ;;
        esac
      done
      # --games/--ai on their own suppress the default; --all keeps everything.
      if [ "$EXPLICIT" -eq 1 ]; then DO_DEFAULT=0; fi
      for arg in "$@"; do [ "$arg" = "--all" ] && DO_DEFAULT=1; done

      MOUNT="$(mktemp -d /run/esnixi-backup.XXXXXX)"
      SNAPROOT=""

      cleanup() {
        set +e
        if mountpoint -q "$MOUNT"; then umount "$MOUNT"; fi
        rmdir "$MOUNT" 2>/dev/null || true
        if [ -n "$SNAPROOT" ] && [ -d "$SNAPROOT" ]; then
          for s in "$SNAPROOT"/*; do
            [ -d "$s" ] && btrfs subvolume delete "$s" >/dev/null 2>&1 || true
          done
          rmdir "$SNAPROOT" 2>/dev/null || true
        fi
      }
      trap cleanup EXIT

      echo ">> mounting $NFS_HOST:$NFS_EXPORT"
      mount -t nfs -o vers=4.1 "$NFS_HOST:$NFS_EXPORT" "$MOUNT"

      SNAPROOT="$(mktemp -d /.esnixi-backup-snaps.XXXXXX)"

      # snapshot <live-path> <snap-name> -> echoes the read-only snapshot path.
      # Falls back to the live path if it is not a btrfs subvolume.
      snapshot() {
        local live="$1" snap="$SNAPROOT/$2"
        if btrfs subvolume show "$live" >/dev/null 2>&1; then
          btrfs subvolume snapshot -r "$live" "$snap" >/dev/null
          echo "$snap"
        else
          echo "$live"
        fi
      }

      # rsync one tree into <dest-dir>/<label>/<subdir>
      sync_tree() {
        local src="$1" dest="$2"; shift 2
        mkdir -p "$dest"
        # shellcheck disable=SC2086
        rsync -aHAX --numeric-ids --delete --info=stats2 $DRY "$@" "$src"/ "$dest"/
      }

      if [ "$DO_DEFAULT" -eq 1 ]; then
        TARGET="$MOUNT/esnixi-$DATE"
        echo ">> [system] -> $TARGET"
        mkdir -p "$TARGET"
        R="$(snapshot / root)"
        H="$(snapshot /home home)"
        P="$(snapshot /persist persist)"
        # Exclude reproducible / regenerable / volatile paths that live under /.
        sync_tree "$R" "$TARGET/root" \
          --exclude=/nix --exclude=/proc --exclude=/sys --exclude=/dev \
          --exclude=/run --exclude=/tmp --exclude=/var/tmp \
          --exclude=/var/lib/docker --exclude=/var/lib/ollama \
          --exclude=/var/lib/vllm --exclude=/mnt --exclude=/home
        sync_tree "$H" "$TARGET/home" \
          --exclude='/*/.cache' --exclude='/*/.local/share/Trash'
        sync_tree "$P" "$TARGET/persist"
        echo "$DATE  host=esnixi  set=system+home+persist" > "$TARGET/BACKUP_INFO"
        echo ">> [system] done: $TARGET"
      fi

      if [ "$DO_GAMES" -eq 1 ]; then
        TARGET="$MOUNT/esnixi-games-$DATE"
        echo ">> [games] -> $TARGET"
        G="$(snapshot /mnt/games games)"
        sync_tree "$G" "$TARGET"
        echo "$DATE  host=esnixi  set=games" > "$TARGET/BACKUP_INFO"
        echo ">> [games] done: $TARGET"
      fi

      if [ "$DO_AI" -eq 1 ]; then
        TARGET="$MOUNT/esnixi-ai-$DATE"
        echo ">> [ai] -> $TARGET"
        mkdir -p "$TARGET"
        OL="$(snapshot ${config.my.paths.ollamaHome} ollama)"
        VL="$(snapshot ${config.my.paths.vllmHome} vllm)"
        sync_tree "$OL" "$TARGET/ollama"
        sync_tree "$VL" "$TARGET/vllm"
        echo "$DATE  host=esnixi  set=ai-models" > "$TARGET/BACKUP_INFO"
        echo ">> [ai] done: $TARGET"
      fi

      echo ">> backup complete"
    '';
  };
in
{
  environment.systemPackages = [ esnixiBackup ];

  # Weekly automatic backup of the default (system + home + persist) set.
  # AI models and games are intentionally NOT in the timer — run
  # `esnixi-backup --ai` / `--games` by hand when you want those.
  systemd.services.esnixi-backup = {
    description = "esnixi backup to Synology NFS (system + home + persist)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${esnixiBackup}/bin/esnixi-backup";
      # rsync + btrfs snapshot + nfs mount all need root.
      User = "root";
      IOSchedulingClass = "idle";
      Nice = 15;
    };
  };

  systemd.timers.esnixi-backup = {
    description = "Weekly esnixi backup to Synology NFS";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Sun 03:00";
      Persistent = true;
      RandomizedDelaySec = "30m";
    };
  };
}
