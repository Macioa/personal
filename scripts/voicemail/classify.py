"""Voicemail .amr -> transcript + delete verdict (JSON on stdout).

Usage: python classify.py <file.amr> <saved: 0|1>
Whisper model/VAD: same amr settings as scripts/transcribe/main.py.
Filters (local.env): empty (< VOICEMAIL_MIN_WORDS words), VOICEMAIL_FILTER_PATTERNS_A/B regexes. Saved contacts exempt from A/B.
"""
import json, re, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "transcribe"))
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "vector"))
import main, reformat, transcribe
from db import env

# Filters from env or local.env
MIN_WORDS = int(env("VOICEMAIL_MIN_WORDS") or 3)
RULES = {"a": env("VOICEMAIL_FILTER_PATTERNS_A"), "b": env("VOICEMAIL_FILTER_PATTERNS_B")}


def verdict(text, saved):
    if len(text.split()) < MIN_WORDS:
        return "empty"
    if saved:
        return None
    return next((k for k, rx in RULES.items() if rx and re.search(rx, text, re.I)), None)


def run(src, saved):
    audio = reformat.load_audio(Path(src), "amr")
    text = " ".join(w.word.strip() for w in transcribe.words(audio, main.MODEL["amr"], **main.VAD["amr"]))
    print(json.dumps({"transcript": text, "delete": verdict(text, saved == "1")}))


if __name__ == "__main__":
    run(*sys.argv[1:])
