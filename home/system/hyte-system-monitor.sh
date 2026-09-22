#!/usr/bin/env bash
set -u

PATH=/run/current-system/sw/bin:/etc/profiles/per-user/celes/bin:$PATH
state_dir="${XDG_RUNTIME_DIR:-/tmp}/hyte-system-monitor"
mkdir -p "$state_dir"

read -r cpu user nice system idle iowait irq softirq steal _ < /proc/stat
total=$((user + nice + system + idle + iowait + irq + softirq + steal))
idle_total=$((idle + iowait))
cpu_usage=0
if read -r prev_total prev_idle < "$state_dir/cpu" 2>/dev/null; then
  delta_total=$((total - prev_total))
  delta_idle=$((idle_total - prev_idle))
  if ((delta_total > 0)); then
    cpu_usage=$(awk -v total="$delta_total" -v idle="$delta_idle" 'BEGIN { printf "%.2f", 100 * (total-idle) / total }')
  fi
fi
printf '%s %s\n' "$total" "$idle_total" > "$state_dir/cpu"

ram_usage=$(awk '/MemTotal:/ {total=$2} /MemAvailable:/ {avail=$2} END {printf "%.2f", 100*(total-avail)/total}' /proc/meminfo)

IFS=',' read -r gpu_usage gpu_used gpu_total gpu_temp gpu_power < <(
  nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw \
    --format=csv,noheader,nounits 2>/dev/null | head -n1 | tr -d ' '
)
gpu_usage=${gpu_usage:-0}
gpu_used=${gpu_used:-0}
gpu_total=${gpu_total:-1}
gpu_temp=${gpu_temp:-0}
gpu_power=${gpu_power:-0}
gpu_mem_usage=$(awk -v used="${gpu_used:-0}" -v total="${gpu_total:-1}" 'BEGIN {printf "%.2f", 100*used/total}')

read -r disk_usage disk2_usage < <(
  df -P / /mnt/fast | awk 'NR > 1 {gsub(/%/, "", $5); value[$6]=$5} END {print value["/"], value["/mnt/fast"]}'
)

sensor_data=$(sensors 2>/dev/null)
sensor_value() {
  awk -v label="$1" '$0 ~ "^[[:space:]]*" label ":" {gsub(/[+°C]/, "", $2); print $2; exit}' <<< "$sensor_data"
}
cpu_temp=$(sensor_value Tctl)
mobo_temp=$(sensor_value Motherboard)
chipset_temp=$(sensor_value Chipset)

cpu_power=0
for name in /sys/class/hwmon/hwmon*/name; do
  if [[ -r "$name" ]] && [[ $(<"$name") == *asusec* ]]; then
    hwmon=${name%/name}
    if [[ -r "$hwmon/in0_input" && -r "$hwmon/curr1_input" ]]; then
      cpu_power=$(awk -v volts="$(<"$hwmon/in0_input")" -v amps="$(<"$hwmon/curr1_input")" \
        'BEGIN {printf "%.2f", volts*amps/1000000}')
    fi
    break
  fi
done

network=$(awk -F '[: ]+' '$2 ~ /^(enp5s0f0|enp5s0f1|br0)$/ {rx += $3; tx += $11} END {print rx+0, tx+0}' /proc/net/dev)

printf '%s\n' \
  "$cpu_usage" "$ram_usage" "$gpu_usage" "$gpu_mem_usage" \
  "${disk_usage:-0}" "${disk2_usage:-0}" "${cpu_temp:-0}" "$gpu_temp" \
  "${mobo_temp:-0}" "${chipset_temp:-0}" "$cpu_power" "$gpu_power" "$network"
