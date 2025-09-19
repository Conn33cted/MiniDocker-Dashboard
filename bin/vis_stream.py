#!/usr/bin/env python3
import os, sys, json, time, subprocess, shlex, shutil
import numpy as np

OUT = os.path.expanduser('~/dashboard/vis.json')

RATE = 48000
FRAME = 512        # rozmiar FFT okna
HOP   = 256        # krok (przesunięcie)
BANDS = 32
FLOOR_DB = -80.0
SMOOTH = 0.6
WRITE_HZ = 45

def pick_monitor_name():
    """Wybierz nazwę monitor source z pactl: najpierw RUNNING, potem pierwszy."""
    try:
        out = subprocess.check_output(["pactl", "list", "short", "sources"], text=True)
    except Exception as e:
        print("[vis] pactl not available:", e)
        return None

    lines = [l.strip() for l in out.splitlines() if l.strip()]
    monitors = []
    for l in lines:
        parts = l.split('\t')  # index, name, driver, format, state
        if len(parts) >= 5 and parts[1].endswith('.monitor'):
            monitors.append((parts[1], parts[4]))  # (name, state)

    if not monitors:
        return None

    for name, state in monitors:
        if str(state).upper() == "RUNNING":
            return name
    return monitors[0][0]

def make_filterbank(nfft, sr, bands):
    fmin, fmax = 40.0, min(sr/2.0, 18000.0)
    edges = np.geomspace(fmin, fmax, bands+1)
    freqs = np.fft.rfftfreq(nfft, 1.0/sr)
    maps = []
    for b in range(bands):
        lo, hi = edges[b], edges[b+1]
        idx = np.where((freqs >= lo) & (freqs < hi))[0]
        if len(idx) == 0:
            idx = np.array([np.argmin(np.abs(freqs - ((lo+hi)/2)))])
        row = np.zeros_like(freqs, dtype=np.float32)
        row[idx] = 1.0 / len(idx)
        maps.append(row)
    return np.stack(maps, axis=0)  # [bands, bins]

def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)

    if shutil.which("parec") is None:
        print("[vis] ERROR: brak 'parec'. Zainstaluj: sudo apt install pulseaudio-utils (lub pipewire-pulse).")
        sys.exit(1)

    mon = pick_monitor_name()
    if not mon:
        print("[vis] ERROR: nie znaleziono żadnego monitor source (pactl list short sources | grep monitor).")
        sys.exit(1)

    print(f"[vis] using monitor: {mon}")

    cmd = f"parec -d {shlex.quote(mon)} --format=s16le --rate={RATE} --channels=1 --latency-msec=5"
    proc = subprocess.Popen(
        shlex.split(cmd),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        bufsize=0,
        env={**os.environ, "PULSE_LATENCY_MSEC": "5"}
    )

    fb = make_filterbank(FRAME, RATE, BANDS)
    last = np.zeros(BANDS, dtype=np.float32)

    byte_buffer = bytearray()
    bytes_per_sample = 2  # s16le
    samples_per_hop = HOP
    target_dt = 1.0 / WRITE_HZ
    win = np.hanning(FRAME).astype(np.float32)

    # bufor przesuwny na ramkę FFT
    ring = np.zeros(FRAME, dtype=np.float32)

    try:
        t_next = time.time()
        while True:
            chunk = proc.stdout.read(4096)
            if not chunk:
                time.sleep(0.01)
                continue
            byte_buffer.extend(chunk)

            need_bytes = samples_per_hop * bytes_per_sample
            while len(byte_buffer) >= need_bytes:
                hop = byte_buffer[:need_bytes]
                del byte_buffer[:need_bytes]
                hop_i16 = np.frombuffer(hop, dtype=np.int16)
                hop_f = hop_i16.astype(np.float32) / 32768.0

                ring = np.concatenate([ring, hop_f])[-FRAME:]

                if ring.shape[0] < FRAME:
                    continue

                X = np.fft.rfft(ring * win)
                mag = np.abs(X).astype(np.float32)
                mag[mag <= 1e-9] = 1e-9
                db = 20.0 * np.log10(mag)

                band_vals = fb @ db
                band_vals = np.clip((band_vals - FLOOR_DB) / (-FLOOR_DB), 0.0, 1.0)
                last = SMOOTH * last + (1.0 - SMOOTH) * band_vals

            now = time.time()
            if now >= t_next:
                try:
                    tmp = OUT + ".tmp"
                    with open(tmp, "w") as f:
                        json.dump({"bands": last.tolist()}, f, separators=(",", ":"))
                    os.replace(tmp, OUT)  # atomowy zapis
                except Exception as e:
                    print("[vis] write error:", e)
                t_next = now + target_dt

    except KeyboardInterrupt:
        pass
    finally:
        try:
            proc.terminate()
        except Exception:
            pass

if __name__ == "__main__":
    main()
