#!/usr/bin/env bash
set -euo pipefail

HTML="file:///home/anti/dashboard/index.html"
PROFILE_DIR="/home/anti/.cache/dashboard-chromium"
W=960; H=640

# 0) Współrzędne małego monitora (po rozdzielczości 960/640)
line="$(xrandr --listmonitors | grep -E ' 960/.*640' || true)"
read -r X Y <<<"$(sed -E 's/.*\+([0-9]+)\+([0-9]+)/\1 \2/' <<<"${line:-+0+0}" | awk '{print $1, $2}')"

# 1) Przygotuj profil z wyłączonym tłumaczeniem (Preferences & Local State)
mkdir -p "$PROFILE_DIR/Default" "$PROFILE_DIR/Crashpad" "$PROFILE_DIR/cache"
# Preferences (w katalogu Default/)
cat > "$PROFILE_DIR/Default/Preferences" <<'JSON'
{
  "intl": {"accept_languages":"pl-PL,pl"},
  "translate":{"enabled": false, "enabled_on_page": false, "recent_target":"pl"},
  "profile":{"exit_type":"None"}
}
JSON
# Local State (w katalogu profilu głównego)
cat > "$PROFILE_DIR/Local State" <<'JSON'
{
  "accept_languages": "pl-PL,pl",
  "translate":{"enabled": false},
  "browser":{"enabled_labs_experiments":["TranslateUI@2:disable"]}
}
JSON

# 1,5) Start exporter stats.json (restart jeśli był już uruchomiony)
pkill -f dashboard_stats.sh || true
"$HOME/bin/dashboard_stats.sh" &

# --- START exporterów (przed chromium) ---
pkill -f dashboard_stats.sh 2>/dev/null || true
pkill -f nowplaying_export.sh 2>/dev/null || true
"$HOME/bin/dashboard_stats.sh" & disown
"$HOME/bin/nowplaying_export.sh" & disown
# --- KONIEC sekcji exporterów ---

# --- NOW PLAYING exporter (Spotify only) ---
NP_PIDFILE="/tmp/nowplaying.pid"
# zabij stary, jeśli był
if [[ -f "$NP_PIDFILE" ]]; then
  kill "$(cat "$NP_PIDFILE")" 2>/dev/null || true
  rm -f "$NP_PIDFILE"
fi
# odpal pętlę w tle
( while true; do ~/bin/nowplaying_export.sh; sleep 1; done ) >/dev/null 2>&1 &
echo $! > "$NP_PIDFILE"


# 2) Odpal Chromium jako osobna instancja z unikalną klasą i profilem
chromium \
  --app="$HTML" \
  --class=DashboardApp \
  --user-data-dir="$PROFILE_DIR" \
  --window-position=${X:-0},${Y:-0} \
  --window-size=${W},${H} \
  --kiosk \
  --lang=pl \
  --accept-lang=pl-PL,pl \
  --disable-translate \
  --disable-features=Translate,TranslateUI,LanguageDetectionDynamic,ForceTranslationUI,OfferTranslateFrom \
  --disable-component-update \
  --disable-infobars \
  --no-default-browser-check \
  --no-first-run \
  --test-type \
  --disk-cache-dir="$PROFILE_DIR/cache" \
  --allow-file-access-from-files \
  --disable-session-crashed-bubble &
PID=$!
echo "$PID" > /tmp/dashboard.pid

# 3) Po utworzeniu okna: ustaw pozycję/rozmiar i ukryj z paska (z retry)
if command -v xdotool >/dev/null 2>&1 && command -v wmctrl >/dev/null 2>&1; then
  for i in {1..15}; do
    sleep 0.2
    wid="$(xdotool search --class 'DashboardApp' | head -n1 || true)"
    if [[ -n "${wid}" ]]; then
      wmctrl -i -r "$wid" -e "0,${X:-0},${Y:-0},${W},${H}" || true
      wmctrl -i -r "$wid" -b add,above,sticky,skip_taskbar,skip_pager || true
      break
    fi
  done
fi

# 4) Uruchom devilspie2 (jeśli nie działa) - pilnuje flag okna na wszelki wypadek
pgrep -x devilspie2 >/dev/null || devilspie2 & disown
