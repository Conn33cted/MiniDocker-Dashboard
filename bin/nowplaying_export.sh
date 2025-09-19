#!/usr/bin/env bash
set -euo pipefail

OUT="$HOME/dashboard/nowplaying.json"
TMP="${OUT}.tmp"

# preferuj spotify, ale jak brak - użyj aktywnego
PLAYER="spotify"
if ! playerctl -p "$PLAYER" status >/dev/null 2>&1; then
  # spróbuj aktywnego playera
  if playerctl status >/dev/null 2>&1; then
    PLAYER=""
  else
    # brak playera — heartbeat, ale pusto
    jq -n --arg ts "$(date +%s)" '{status:"stopped", ts: ($ts|tonumber)}' >"$TMP" && mv "$TMP" "$OUT"
    exit 0
  fi
fi

pc(){ playerctl ${PLAYER:+-p "$PLAYER"} "$@"; }

status="$(pc status 2>/dev/null || echo "Stopped")"
title="$(pc metadata xesam:title 2>/dev/null || echo "")"
# artist może być listą – sklej w CSV
artist="$(pc metadata xesam:artist 2>/dev/null | paste -sd", " - || echo "")"
album="$(pc metadata xesam:album 2>/dev/null || echo "")"
art="$(pc metadata mpris:artUrl 2>/dev/null || echo "")"

# czasu:
# mpris:length → µs; position → s (float)
length_us="$(pc metadata mpris:length 2>/dev/null || echo 0)"
pos_ms="$(pc position 2>/dev/null | awk '{print int($1*1000)}' || echo 0)"

length_sec=$(( length_us / 1000000 ))
pos_sec=$(( pos_ms / 1000 ))
ts="$(date +%s)"

jq -n \
  --arg ts "$ts" \
  --arg status "$status" \
  --arg title "$title" \
  --arg artist "$artist" \
  --arg album "$album" \
  --arg art "$art" \
  --argjson position "$pos_sec" \
  --argjson length "$length_sec" \
'{
  ts: ($ts|tonumber),
  status: $status,
  title: $title,
  artist: $artist,
  album: $album,
  art: $art,
  position_sec: $position,
  length_sec: $length
}' >"$TMP" && mv "$TMP" "$OUT"
