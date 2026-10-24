import subprocess, sys

from . import amr, mac, windows

CLEAN = "highpass=f=80,loudnorm=I=-16:TP=-1.5:LRA=11"
LOADERS = {"windows": windows.load_audio, "mac": mac.load_audio, "amr": amr.load_audio}


# ffprobe -show_entries value for src
def probe(src, entries, select=None):
    sel = ["-select_streams", select] if select else []
    return subprocess.run(["ffprobe", "-v", "error", *sel, "-show_entries", entries, "-of", "csv=p=0", str(src)],
                          capture_output=True, text=True).stdout.split()


# Input type from container: amr, mac (QuickTime), windows (mp4)
def detect(src):
    fmt, brand = (probe(src, "format=format_name") or [""])[0], "".join(probe(src, "format_tags=major_brand"))
    if fmt == "amr":
        return "amr"
    if brand == "qt":
        return "mac"
    if brand in ("isom", "mp42", "mp41"):
        return "windows"
    sys.exit(f"unsupported format: {fmt} {brand}")


# Number of audio streams in src
def audio_streams(src):
    out = probe(src, "stream=index", "a")
    if not out:
        sys.exit("no audio stream")
    return len(out)


# Filter graph mixing all audio streams (mic + system) into one
def mix(n):
    return f"{''.join(f'[0:a:{i}]' for i in range(n))}amix=inputs={n}" if n > 1 else "[0:a:0]anull"


# Decode src through filter graph to cleaned 16 kHz mono float32 array
def decode(src, graph):
    import numpy as np
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(src), "-filter_complex", f"{graph},{CLEAN}",
                          "-vn", "-ac", "1", "-ar", "16000", "-f", "f32le", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32)


# Cleaned 16 kHz mono audio for src of type fmt
def load_audio(src, fmt):
    return LOADERS[fmt](src)
