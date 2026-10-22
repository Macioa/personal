"""Meeting recording -> speaker-labeled transcript + compressed archive video.

Usage: python main.py <recording> [num_speakers=2, -1=auto] [model=small] [out_dir=temp/transcripts]
Models (faster-whisper, speed vs accuracy): tiny, base, small, medium,
large-v3-turbo (best speed/accuracy), large-v3 (most accurate), distil-large-v3 (English only).
"""
import sys
from pathlib import Path

import reformat, transcribe


# Parse CLI args with defaults
def args():
    a = sys.argv[1:] + [None] * 4
    return Path(a[0]), int(a[1] or 2), a[2] or "small", Path(a[3] or "temp/transcripts")


# Full process: setup, transcribe, archive
def main(src, n_spk, model, out_dir):
    reformat.ensure_ffmpeg()
    transcribe.ensure_deps()
    out_dir.mkdir(parents=True, exist_ok=True)
    dst = out_dir / src.stem
    audio = reformat.load_audio(src)
    turns = transcribe.diarize(audio, n_spk)
    words = transcribe.words(audio, model)
    transcribe.write(transcribe.group(words, turns), dst)
    reformat.compress(src, dst)


if __name__ == "__main__":
    main(*args())
