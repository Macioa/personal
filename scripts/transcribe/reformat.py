import shutil, subprocess, sys

CLEAN = "highpass=f=80,loudnorm=I=-16:TP=-1.5:LRA=11"


# Install ffmpeg via winget if missing
def ensure_ffmpeg():
    if not shutil.which("ffmpeg"):
        subprocess.call(["winget", "install", "-e", "Gyan.FFmpeg"])
        sys.exit("ffmpeg installed; open a new terminal and rerun")


# Number of audio streams in src
def audio_streams(src):
    out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a", "-show_entries", "stream=index",
                          "-of", "csv=p=0", str(src)], capture_output=True, text=True).stdout.split()
    if not out:
        sys.exit("no audio stream")
    return len(out)


# Filter graph mixing all audio streams (mic + system) into one
def mix(n):
    return f"{''.join(f'[0:a:{i}]' for i in range(n))}amix=inputs={n}" if n > 1 else "[0:a:0]anull"


# Decode src to cleaned 16 kHz mono float32 array
def load_audio(src):
    import numpy as np
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(src), "-filter_complex", f"{mix(audio_streams(src))},{CLEAN}",
                          "-vn", "-ac", "1", "-ar", "16000", "-f", "f32le", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32)


# Archive copy: AV1 CRF55 360p 0.5fps + Opus 12k voip mono -> <dst>.archive.mp4
def compress(src, dst):
    subprocess.check_call([
        "ffmpeg", "-y", "-v", "error", "-i", str(src),
        "-filter_complex", f"[0:v:0]fps=0.5,scale=-2:'min(360,ih)'[v];{mix(audio_streams(src))}[a]", "-map", "[v]", "-map", "[a]",
        "-c:v", "libaom-av1", "-crf", "55", "-b:v", "0", "-cpu-used", "6", "-row-mt", "1",
        "-c:a", "libopus", "-b:a", "12k", "-application", "voip", "-ac", "1",
        "-movflags", "+faststart", str(dst) + ".archive.mp4"])
