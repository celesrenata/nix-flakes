#!/usr/bin/env bash
set -euo pipefail

action="$1"
slot="$2"
active_id="$(hyprctl activeworkspace -j | jq -r '.id // empty')"

# Named and special workspaces use negative/non-numeric IDs. Keep number-key
# dispatches in the first numbered group until a numeric workspace is focused.
if [[ ! "$active_id" =~ ^[1-9][0-9]*$ ]]; then
  active_id=1
fi

group_start=$(( (active_id - 1) / 10 * 10 ))
target=$(( group_start + slot ))
exec hyprctl dispatch "$action" "$target"
