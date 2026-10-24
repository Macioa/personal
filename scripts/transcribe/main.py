"""Meeting recording -> speaker-labeled transcript + compressed archive video.

Usage: python main.py <recording> [num_speakers=2, -1=auto] [model=small] [out_dir=temp/transcripts]
Models (faster-whisper, speed vs accuracy): tiny, base, small, medium,
large-v3-turbo (best speed/accuracy), large-v3 (most accurate), distil-large-v3 (English only).
"""
import platform, sys
from pathlib import Path

import backup, deps, reformat, transcribe

OS = {"Windows": "windows", "Darwin": "mac"}
# Per-format VAD: phone-band amr speech is dropped by default VAD
VAD = {"windows": {"vad": True}, "mac": {"vad": True}, "amr": {"vad": False}}


# Parse CLI args with defaults
def args():
    a = sys.argv[1:] + [None] * 4
    return Path(a[0]), int(a[1] or 2), a[2] or "small", Path(a[3] or "temp/transcripts")


# Full process: setup, transcribe, backup
def main(src, n_spk, model, out_dir):
    deps.ensure_ffmpeg(OS[platform.system()])
    transcribe.ensure_deps()
    out_dir.mkdir(parents=True, exist_ok=True)
    dst = out_dir / src.stem
    fmt = reformat.detect(src)
    audio = reformat.load_audio(src, fmt)
    turns = transcribe.diarize(audio, n_spk)
    words = transcribe.words(audio, model, **VAD[fmt])
    transcribe.write(transcribe.group(words, turns), dst)
    backup.backup(src, dst, fmt)


if __name__ == "__main__":
    main(*args())
