#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-}"
DASH="$HOME/dashboard"                  # tu piszą exportery
FRONT="$HOME/dashboard-project/dashboard"  # tu czyta index.html

case "$MODE" in
  dev)
    # FRONT -> symlinki do żywych JSON-ów
    rm -f "$FRONT/stats.json" "$FRONT/vis.json" "$FRONT/nowplaying.json"
    ln -s "$DASH/stats.json"      "$FRONT/stats.json"
    ln -s "$DASH/vis.json"        "$FRONT/vis.json"
    ln -s "$DASH/nowplaying.json" "$FRONT/nowplaying.json"
    ls -l "$FRONT"/{stats.json,vis.json,nowplaying.json}
    echo "[dev_localize] FRONT ma symlinki do żywych JSON-ów."
    ;;
  clean)
    # FRONT -> placeholders {} (żeby nic z HOME nie wpadło do commita)
    rm -f "$FRONT/stats.json" "$FRONT/vis.json" "$FRONT/nowplaying.json"
    printf '{}\n' > "$FRONT/stats.json"
    printf '{}\n' > "$FRONT/vis.json"
    printf '{}\n' > "$FRONT/nowplaying.json"
    ls -l "$FRONT"/{stats.json,vis.json,nowplaying.json}
    echo "[dev_localize] FRONT ma placeholders ({}). Użyj przed 'git commit'."
    ;;
  *)
    echo "Użycie: $0 {dev|clean}"
    exit 1
    ;;
esac
