#!/usr/bin/env bash
set -euo pipefail

# === ŚCIEŻKI ===
PROFILE_DIR="$HOME/.cache/dashboard-chromium"

# Auto-wybór index.html (repo → symlink)
if   [[ -f "$HOME/dashboard-project/dashboard/index.html" ]]; then
  HTML="file://$HOME/dashboard-project/dashboard/index.html"
elif [[ -f "$HOME/dashboard/index.html" ]]; then
  HTML="file://$HOME/dashboard/index.html"
else
  echo "ERROR: Nie znalazłem index.html ani w ~/dashboard-project/dashboard ani w ~/dashboard" >&2
  exit 1
fi

# === ROZMIAR/POZYCJA OKNA ===
W=960; H=640
# Szukamy monitora 960/640 (dopasuj jeśli inny)
line="$(xrandr --listmonitors | grep -E ' 960/.*640' || true)"
read -r X Y <<<"$(sed -E 's/.*\+([0-9]+)\+([0-9]+)/\1 \2/' <<<"${line:-+0+0}" | awk '{print $1, $2}')"

# === PROFIL CHROMIUM (wyłączone tłumaczenie) ===
mkdir -p "$PROFILE_DIR/Default" "$PROFILE_DIR/Crashpad" "$PROFILE_DIR/cache"
cat > "$PROFILE_DIR/Default/Preferences" <<'JSON'
{
  "intl": {"accept_languages":"pl-PL,pl"},
  "translate":{"enabled": false, "enabled_on_page": false, "recent_target":"pl"},
  "profile":{"exit_type":"None"}
}
JSON
cat > "$PROFILE_DIR/Local State" <<'JSON'
{
  "accept_languages": "pl-PL,pl",
  "translate":{"enabled": false},
  "browser":{"enabled_labs_experiments":["TranslateUI@2:disable"]}
}
JSON

# === EXPORTERY (pojedyncze uruchomienia, bez duplikatów) ===
pkill -f dashboard_stats.sh      2>/dev/null || true
pkill -f nowplaying_export.sh    2>/dev/null || true

# Jeśli masz symlinki do ~/bin/… to działają; jeśli nie – podmień na ~/dashboard-project/bin/…
"$HOME/bin/dashboard_stats.sh"    >/dev/null 2>&1 & disown
"$HOME/bin/nowplaying_export.sh"  >/dev/null 2>&1 & disown

# (opcjonalnie) jeśli exporter NowPlaying nie ma własnej pętli w środku, a chcesz watchdog,
# odkomentuj te linie i skasuj powyższe jedno-shoty:
# NP_PIDFILE="/tmp/nowplaying.pid"
# [[ -f "$NP_PIDFILE" ]] && { kill "$(cat "$NP_PIDFILE")" 2>/dev/null || true; rm -f "$NP_PIDFILE"; }
# ( while true; do "$HOME/bin/nowplaying_export.sh"; sleep 1; done ) >/dev/null 2>&1 &
# echo $! > "$NP_PIDFILE"

# === START CHROMIUM (app window) ===
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

# === DOSTRAJANIE OKNA (po starcie)
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

# === DEVILSPIE2 (opcjonalny strażnik)
pgrep -x devilspie2 >/dev/null || devilspie2 & disown

# --- NOW PLAYING exporter watchdog ---
pkill -f nowplaying_export.sh 2>/dev/null || true
nohup bash -c 'while true; do "$HOME/dashboard-project/bin/nowplaying_export.sh"; sleep 1; done' \
  >/tmp/np.log 2>&1 & disown
