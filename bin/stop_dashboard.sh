#!/usr/bin/env bash
set -euo pipefail

PIDFILE="/tmp/dashboard.pid"
PROFILE_DIR="/home/anti/.cache/dashboard-chromium"

# 1) grzeczne zamknięcie okna (jeśli znajdziemy)
if command -v xdotool >/dev/null 2>&1; then
  if wid="$(xdotool search --class 'DashboardApp' | head -n1 2>/dev/null)"; then
    xdotool windowclose "$wid" || true
    sleep 0.3
  fi
  # fallback po tytule (jakby klasa nie siadła)
  if wid="$(xdotool search --name 'Dashboard' | head -n1 2>/dev/null)"; then
    xdotool windowclose "$wid" || true
    sleep 0.3
  fi
fi

# 2) spróbuj po PID (może już nie istnieć – ignorujemy błędy)
if [[ -f "$PIDFILE" ]]; then
  PID="$(cat "$PIDFILE" 2>/dev/null || true)"
  [[ -n "${PID:-}" ]] && kill "$PID" 2>/dev/null || true
  rm -f "$PIDFILE" || true
fi

# 3) utnij wszystkie procesy dashboardu po profilu user-data-dir
pkill -f -- "--user-data-dir=${PROFILE_DIR}" || true

# 4) dobij exporter statystyk
pkill -f dashboard_stats.sh || true
pkill -f dashboard_stats.sh 2>/dev/null || true
pkill -f nowplaying_export.sh 2>/dev/null || true

# NOW PLAYING exporter
if [[ -f /tmp/nowplaying.pid ]]; then
  kill "$(cat /tmp/nowplaying.pid)" 2>/dev/null || true
  rm -f /tmp/nowplaying.pid
fi

# (opcjonalnie) posprzątaj cache profilu, jeśli chcesz świeży start
# rm -rf "$PROFILE_DIR" || true

echo "dashboard: stopped"
