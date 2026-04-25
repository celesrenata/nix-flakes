#!/usr/bin/env bash
# Reads idle settings from illogical-impulse config.json and applies to hypridle

CONFIG="$HOME/.config/illogical-impulse/config.json"

if [ ! -f "$CONFIG" ]; then
    echo "Config not found: $CONFIG"
    exit 1
fi

DIM=$(python3 -c "import json; c=json.load(open('$CONFIG')); print(c.get('idle',{}).get('dimTimeout', 300))")
LOCK=$(python3 -c "import json; c=json.load(open('$CONFIG')); print(c.get('idle',{}).get('lockTimeout', 420))")
DPMS=$(python3 -c "import json; c=json.load(open('$CONFIG')); print(c.get('idle',{}).get('dpmsTimeout', 600))")
SUSPEND_EN=$(python3 -c "import json; c=json.load(open('$CONFIG')); print(c.get('idle',{}).get('suspendEnabled', False))")
SUSPEND_T=$(python3 -c "import json; c=json.load(open('$CONFIG')); print(c.get('idle',{}).get('suspendTimeout', 900))")

SUSPEND_BLOCK=""
if [ "$SUSPEND_EN" = "True" ]; then
    SUSPEND_BLOCK="
listener {
    timeout = $SUSPEND_T
    on-timeout = pidof steam || systemctl suspend || loginctl suspend
}"
fi

cat > "$HOME/.config/hypr/hypridle.conf" << EOF
general {
    lock_cmd = pidof hyprlock || hyprlock
    before_sleep_cmd = loginctl lock-session
}

listener {
    timeout = $DIM
    on-timeout = brightnessctl | grep "Current" | awk '{ print \$3 }' > ~/.cache/idle-brightness && brightnessctl set 10%
    on-resume = brightnessctl set \$(cat ~/.cache/idle-brightness)
}

listener {
    timeout = $LOCK
    on-timeout = pidof hyprlock || hyprlock
}

listener {
    timeout = $DPMS
    on-timeout = hyprctl dispatch dpms off
    on-resume = hyprctl dispatch dpms on; hyprctl setcursor Bibata-Modern-Classic 24
}
$SUSPEND_BLOCK
EOF

# Restart hypridle to pick up changes
pkill hypridle
sleep 0.5
nohup hypridle &>/dev/null & disown

echo "Hypridle config applied (dim=${DIM}s lock=${LOCK}s dpms=${DPMS}s suspend=${SUSPEND_EN}/${SUSPEND_T}s)"
