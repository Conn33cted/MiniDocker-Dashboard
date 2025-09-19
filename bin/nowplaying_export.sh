#!/usr/bin/env bash
set -euo pipefail

OUT="$HOME/dashboard/nowplaying.json"

# Jeśli spotify nie działa – czyszczony JSON
if ! playerctl -p spotify status >/dev/null 2>&1; then
  jq -n '{status:"stopped"}' > "$OUT"
  exit 0
fi

status="$(playerctl -p spotify status 2>/dev/null || echo "Stopped")"
title="$(playerctl -p spotify metadata xesam:title 2>/dev/null || echo "")"
artist="$(playerctl -p spotify metadata xesam:artist 2>/dev/null | paste -sd", " - || echo "")"
album="$(playerctl -p spotify metadata xesam:album 2>/dev/null || echo "")"
art="$(playerctl -p spotify metadata mpris:artUrl 2>/dev/null || echo "")"

# długości/pozycje
# mpris:length zwraca mikrosekundy
length_us="$(playerctl -p spotify metadata mpris:length 2>/dev/null || echo 0)"
pos_ms="$(playerctl -p spotify position 2>/dev/null | awk '{print int($1*1000)}' || echo 0)"

length_sec=$(( length_us / 1000000 ))
pos_sec=$(( pos_ms / 1000 ))

# Spotify czasem zwraca file:///… – zostawiamy jak jest, Chromium to ogarnie
jq -n \
  --arg status "$status" \
  --arg title "$title" \
  --arg artist "$artist" \
  --arg album "$album" \
  --arg art "$art" \
  --argjson position "$pos_sec" \
  --argjson length "$length_sec" \
  '{
    status: $status,
    title: $title,
    artist: $artist,
    album: $album,
    art: $art,
    position_sec: $position,
    length_sec: $length
  }' > "$OUT"
