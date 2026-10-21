"""Speaker-labeled transcript from a meeting recording (local, free).

Usage: python transcribe.py <recording> [num_speakers=2, -1=auto] [model=small] [out_dir=temp/transcripts]
Writes <out_dir>/<recording>.md and .json.

Models (faster-whisper, speed vs accuracy): tiny, base, small, medium,
large-v3-turbo (best speed/accuracy), large-v3 (most accurate), distil-large-v3 (English only).
"""
import importlib.util, json, shutil, subprocess, sys, tarfile, urllib.request
from pathlib import Path

PKGS = {"faster_whisper": "faster-whisper", "sherpa_onnx": "sherpa-onnx", "soundfile": "soundfile", "numpy": "numpy"}
MODELS = Path.home() / ".cache" / "transcribe"
REL = "https://github.com/k2-fsa/sherpa-onnx/releases/download/"
SEG = MODELS / "sherpa-onnx-pyannote-segmentation-3-0" / "model.int8.onnx"
EMB = MODELS / "nemo_en_titanet_small.onnx"


def setup():
    missing = [p for m, p in PKGS.items() if not importlib.util.find_spec(m)]
    if missing:
        subprocess.check_call([sys.executable, "-m", "pip", "install", *missing])
    if not shutil.which("ffmpeg"):
        subprocess.call(["winget", "install", "-e", "Gyan.FFmpeg"])
        sys.exit("ffmpeg installed; open a new terminal and rerun")
    MODELS.mkdir(parents=True, exist_ok=True)
    if not SEG.exists():
        tar = MODELS / "seg.tar.bz2"
        urllib.request.urlretrieve(REL + "speaker-segmentation-models/sherpa-onnx-pyannote-segmentation-3-0.tar.bz2", tar)
        with tarfile.open(tar) as t:
            t.extractall(MODELS, filter="data")
        tar.unlink()
    if not EMB.exists():
        urllib.request.urlretrieve(REL + "speaker-recongition-models/nemo_en_titanet_small.onnx", EMB)


def to_wav(src, wav):
    n = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a", "-show_entries", "stream=index",
                        "-of", "csv=p=0", src], capture_output=True, text=True).stdout.split()
    if not n:
        sys.exit("no audio stream")
    # Multiple streams (mic + system audio) are mixed into one
    mix = [f"[0:a:{i}]" for i in range(len(n))]
    af = "highpass=f=80,loudnorm=I=-16:TP=-1.5:LRA=11"
    flt = f"{''.join(mix)}amix=inputs={len(n)},{af}" if len(n) > 1 else f"[0:a:0]{af}"
    subprocess.check_call(["ffmpeg", "-y", "-v", "error", "-i", src, "-filter_complex", flt, "-vn",
                           "-ac", "1", "-ar", "16000", "-c:a", "pcm_s16le", wav])


def main():
    src = Path(sys.argv[1])
    n_spk = int(sys.argv[2]) if len(sys.argv) > 2 else 2
    model_name = sys.argv[3] if len(sys.argv) > 3 else "small"
    out_dir = Path(sys.argv[4] if len(sys.argv) > 4 else "temp/transcripts")
    out_dir.mkdir(parents=True, exist_ok=True)
    dst = out_dir / src.stem
    setup()
    import soundfile as sf, sherpa_onnx
    from faster_whisper import WhisperModel

    wav = src.with_suffix(".16k.wav")
    to_wav(str(src), str(wav))
    audio, _ = sf.read(wav, dtype="float32")
    wav.unlink()

    # Diarize
    cfg = sherpa_onnx.OfflineSpeakerDiarizationConfig(
        segmentation=sherpa_onnx.OfflineSpeakerSegmentationModelConfig(
            pyannote=sherpa_onnx.OfflineSpeakerSegmentationPyannoteModelConfig(model=str(SEG))),
        embedding=sherpa_onnx.SpeakerEmbeddingExtractorConfig(model=str(EMB)),
        clustering=sherpa_onnx.FastClusteringConfig(num_clusters=n_spk, threshold=0.5),
        min_duration_on=0.3, min_duration_off=0.5)
    turns = [(t.start, t.end, t.speaker) for t in
             sherpa_onnx.OfflineSpeakerDiarization(cfg).process(audio).sort_by_start_time()]

    # Transcribe (VAD skips silence; timestamps stay on original timeline)
    segs, info = WhisperModel(model_name, device="auto", compute_type="int8").transcribe(
        audio, vad_filter=True, word_timestamps=True, condition_on_previous_text=False, beam_size=5)
    words = [w for s in segs for w in s.words]

    # Word -> speaker with max overlap, else nearest turn
    def spk(a, b):
        if not turns:
            return -1
        best = max(turns, key=lambda t: min(b, t[1]) - max(a, t[0]))
        if min(b, best[1]) - max(a, best[0]) > 0:
            return best[2]
        return min(turns, key=lambda t: min(abs(a - t[1]), abs(b - t[0])))[2]

    out = []
    for w in words:
        s = spk(w.start, w.end)
        if out and out[-1]["speaker"] == s and w.start - out[-1]["end"] < 2.0:
            out[-1]["text"] += w.word
            out[-1]["end"] = w.end
        else:
            out.append({"speaker": s, "start": w.start, "end": w.end, "text": w.word})

    order = {}
    for t in out:
        t["speaker"] = order.setdefault(t["speaker"], len(order) + 1)
        t["text"] = t["text"].strip()

    ts = lambda x: f"{int(x // 3600):02}:{int(x % 3600 // 60):02}:{int(x % 60):02}"
    dst.with_suffix(".json").write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
    dst.with_suffix(".md").write_text(
        "".join(f"[{ts(t['start'])}] Speaker {t['speaker']}: {t['text']}\n\n" for t in out), encoding="utf-8")
    print(f"{len(order)} speakers, {len(out)} turns, lang={info.language} -> {dst.with_suffix('.md')}")


if __name__ == "__main__":
    main()
