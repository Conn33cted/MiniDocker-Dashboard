# MiniDocker-Dashboard

Mini dashboard na mały ekran (inspirowany **Bloomberg vibe**).  
Zawiera:
- **Zegar / flipclock**  
- **Markets**: FX + wolniejsze Stocks, statusy Tokyo/London/NY, morphująca waluta  
- **Now Playing**: kolory z okładki + FFT visualizer  

---

## Wymagania

Do działania potrzebne są:
- `chromium`
- `xdotool`
- `wmctrl`
- `devilspie2`
- `jq`
- `playerctl`
- `python3-venv`
- `pulseaudio-utils` (lub `pipewire` z `pactl/parec`)

---

## Instalacja pakietów (Ubuntu/Mint/Debian)

```bash
sudo apt update
sudo apt install -y chromium xdotool wmctrl devilspie2 jq playerctl python3-venv python3-pip pulseaudio-utils
```

---

## Szybki start (czysta maszyna)

```bash
# Klon repozytorium
git clone https://github.com/Conn33cted/MiniDocker-Dashboard.git ~/dashboard-project
cd ~/dashboard-project

# Symlink do dashboard
ln -sfn ~/dashboard-project/dashboard ~/dashboard

# Wirtualne środowisko i numpy
python3 -m venv ~/vis-venv && ~/vis-venv/bin/pip install --upgrade pip numpy

# Konfiguracja devilspie2
mkdir -p ~/.config/devilspie2
cp -f configs/devilspie2/dashboard.lua ~/.config/devilspie2/dashboard.lua
pkill devilspie2 2>/dev/null || true; devilspie2 & disown

# Symlinki do binarek
mkdir -p ~/bin
ln -sfn ~/dashboard-project/bin/{dashboard,launch_dashboard.sh,stop_dashboard.sh,dashboard_stats.sh,nowplaying_export.sh,vis_stream.py} ~/bin/

# Lokalizacja dev
./bin/dev_localize.sh dev

# Źródło audio (przykład)
PULSE_SOURCE="alsa_output.pci-0000_00_1f.3.analog-stereo.monitor"

# Start procesów w tle
nohup ~/vis-venv/bin/python ~/dashboard-project/bin/vis_stream.py >/tmp/vis.log 2>&1 & disown
nohup ~/dashboard-project/bin/dashboard_stats.sh >/tmp/stats.log 2>&1 & disown
nohup bash -c 'while true; do ~/dashboard-project/bin/nowplaying_export.sh; sleep 1; done' >/tmp/np.log 2>&1 & disown

# Start dashboardu
dashboard start
```

---

## Wskazówka (monitor audio)

Sprawdzenie dostępnych źródeł audio:  

```bash
pactl list short sources | awk -F'\t' '$2 ~ /.monitor$/ {print NR")",$2,$5}'
```

---

## Dev ↔ Commit

- Podczas developmentu:  

```bash
./bin/dev_localize.sh dev   # UI czyta żywe JSON-y (symlinki)
```

- Przed commit/push:  

```bash
./bin/dev_localize.sh clean # czyści symlinki i runtime
```

---
