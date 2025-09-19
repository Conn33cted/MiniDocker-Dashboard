#!/usr/bin/env bash
set -euo pipefail

OUT="$HOME/dashboard/stats.json"

# --- helpery ---
num_or_null() {
  # jeśli argument to liczba (int/float), zwróć ją; inaczej "null"
  local v="$1"
  [[ "$v" =~ ^-?[0-9]+([.][0-9]+)?$ ]] && { printf '%s' "$v"; return; }
  printf 'null'
}
first_nonempty() {
  # wywołuj kolejne komendy aż coś zwrócą
  local out
  for cmd in "$@"; do
    out="$(bash -lc "$cmd" 2>/dev/null | sed -e 's/\r$//' | head -n1 || true)"
    [[ -n "$out" ]] && { printf '%s' "$out"; return; }
  done
  printf ''
}

# Upewnij się, że katalog istnieje
mkdir -p "$(dirname "$OUT")"

prev_u=; prev_t=
while :; do
  # ---- CPU % z /proc/stat (bez zewn. zależności) ----
  # metoda różnic – pierwsze przejście może dać pustkę -> 0
  read -r _ u n s rest < /proc/stat
  # u: user, n: nice, s: system, idle to piąte pole:
  idle=$(awk '{print $5}' /proc/stat | head -n1)
  total=$((u + n + s + idle))
  used=$((u + s + n))

  if [[ -n "${prev_t:-}" ]]; then
    du=$((used - prev_u))
    dt=$((total - prev_t))
    cpu=$(( dt>0 ? (100*du/dt) : 0 ))
  else
    cpu=0
  fi
  prev_u=$used; prev_t=$total

  # ---- RAM % ----
# --- RAM % z /proc/meminfo (odporne na lokalizację) ---
mem_total_kb=$(awk '/^MemTotal:/     {print $2}' /proc/meminfo)
mem_avail_kb=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)

if [[ -n "${mem_total_kb:-}" && -n "${mem_avail_kb:-}" && "$mem_total_kb" -gt 0 ]]; then
  mem_used_kb=$(( mem_total_kb - mem_avail_kb ))
  ram=$(( 100 * mem_used_kb / mem_total_kb ))   # 0..100 (int)
else
  ram=0
fi


  # ---- Network bytes (suma wszystkich interfejsów) ----
  # bez bc: sumujemy w awk
  rx_bytes=$(awk 'BEGIN{s=0} {s+=$1} END{print s}' /sys/class/net/*/statistics/rx_bytes 2>/dev/null || echo 0)
  tx_bytes=$(awk 'BEGIN{s=0} {s+=$1} END{print s}' /sys/class/net/*/statistics/tx_bytes 2>/dev/null || echo 0)

  # ---- Uptime & Root disk ----
  uptime_txt="$(uptime -p 2>/dev/null || echo 'up')"
  disk_pct="$(df -h / | awk 'NR==2{print $5}')"

  # ---- CPU temp (najpewniej via lm-sensors / thermal_zone) ----
  cpu_temp_raw="$( first_nonempty \
    "sensors -j 2>/dev/null | jq -r '..|.\"Package id 0\"?.temp1_input? // empty' | head -n1" \
    "for f in /sys/class/thermal/thermal_zone*/temp; do [[ -r \$f ]] && cat \$f; done | awk '{print int(\$1/1000)}' | head -n1" \
  )"
  cpu_temp="$(num_or_null "${cpu_temp_raw:-}")"

  # ---- GPU vendor / temp / util (opcjonalnie) ----
  gpu_vendor="$( first_nonempty \
    "lspci -nn | grep -i ' vga ' | grep -qi nvidia && echo nvidia" \
    "lspci -nn | grep -i ' vga ' | grep -qi amd    && echo amd" \
    "lspci -nn | grep -i ' vga ' | grep -qi intel  && echo intel" \
  )"
  [[ -z "$gpu_vendor" ]] && gpu_vendor="unknown"

  gpu_temp=null
  gpu_util=null

  case "$gpu_vendor" in
    nvidia)
      if command -v nvidia-smi >/dev/null 2>&1; then
        gtemp="$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1)"
        gutil="$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1)"
        gpu_temp="$(num_or_null "${gtemp:-}")"
        gpu_util="$(num_or_null "${gutil:-}")"
      fi
      ;;
    amd)
      atemp="$( first_nonempty \
        "for d in /sys/class/drm/card*/device/hwmon/hwmon*/temp1_input; do [[ -r \$d ]] && cat \$d; done | head -n1 | awk '{print int(\$1/1000)}'" \
      )"
      gpu_temp="$(num_or_null "${atemp:-}")"
      ;;
    intel)
      itemp="$( first_nonempty \
        "for d in /sys/class/thermal/thermal_zone*/type; do t=\$(cat \$d); [[ \$t == \"x86_pkg_temp\" ]] && cat \${d%/type}/temp; done | head -n1 | awk '{print int(\$1/1000)}'" \
      )"
      gpu_temp="$(num_or_null "${itemp:-}")"
      ;;
  esac

  # ---- Load average & kernel ----
  loadavg_txt="$(awk '{print $1","$2","$3}' /proc/loadavg)"
  kernel_txt="$(uname -r)"

  # ---- Zapis JSON (ODPORNY) ----
  # liczby przekazujemy jako LITERAŁY (już z num_or_null), stringi --arg
  jq -n \
    --arg      uptime "$uptime_txt" \
    --arg      disk   "$disk_pct" \
    --arg      vendor "$gpu_vendor" \
    --arg      loadavg "$loadavg_txt" \
    --arg      kernel  "$kernel_txt" \
    --argjson  cpu     "$(num_or_null "$cpu")" \
    --argjson  ram     "$(num_or_null "$ram")" \
    --argjson  net_down "$(num_or_null "$rx_bytes")" \
    --argjson  net_up   "$(num_or_null "$tx_bytes")" \
    --argjson  cpu_temp "$cpu_temp" \
    --argjson  gpu_temp "$gpu_temp" \
    --argjson  gpu_util "$gpu_util" \
    '{
      cpu:       $cpu,
      ram:       $ram,
      net_down:  $net_down,
      net_up:    $net_up,
      uptime:    $uptime,
      disk:      $disk,
      gpu_vendor:$vendor,
      cpu_temp:  $cpu_temp,
      gpu_temp:  $gpu_temp,
      gpu_util:  $gpu_util,
      loadavg:   $loadavg,
      kernel:    $kernel
    }' > "$OUT".tmp && mv -f "$OUT".tmp "$OUT"

  sleep 2
done
