#!/usr/bin/env bash
# Watch distcc distribution across gremlins (in-place refresh)
tput civis
trap 'tput cnorm; exit' INT TERM

declare -A prev_ok
for ip in 10.1.1.12 10.1.1.13 10.1.1.14 10.1.1.15; do prev_ok[$ip]=0; done

clear
while true; do
  tput home
  printf '=== distcc monitor %s ===\n\n' "$(date +%H:%M:%S)"
  total=0
  for g in gremlin-1 gremlin-2 gremlin-3 gremlin-4; do
    count=$(ssh -o ConnectTimeout=2 root@$g "ps -eo comm | grep -c cc1plus" 2>/dev/null | tr -d '[:space:]')
    count=${count:-0}
    bar=$(printf '%*s' "$count" '' | tr ' ' '█')
    printf '  %-10s %3d %-50s\n' "$g:" "$count" "$bar"
    total=$((total + count))
  done
  printf '\n  total:    %3d\n\n' "$total"
  ssh -o ConnectTimeout=2 root@gremlin-1 '
    for ip in 10.1.1.12 10.1.1.13 10.1.1.14 10.1.1.15; do
      data=$(curl -s http://$ip:3633 2>/dev/null)
      ok=$(echo "$data" | grep dcc_compile_ok | awk "{print \$2}")
      err=$(echo "$data" | grep dcc_compile_error | awk "{print \$2}")
      echo "$ip ${ok:-0} ${err:-0}"
    done' 2>/dev/null | while read ip ok err; do
    delta=$((ok - ${prev_ok[$ip]:-0}))
    prev_ok[$ip]=$ok
    printf '  %-12s total: %-8s err: %-4s  (+%d/2s)\n' "$ip" "$ok" "$err" "$delta"
  done
  tput ed
  sleep 2
done
