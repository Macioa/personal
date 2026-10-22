import importlib.util, json, subprocess, sys, tarfile, urllib.request
from pathlib import Path

PKGS = {"faster_whisper": "faster-whisper", "sherpa_onnx": "sherpa-onnx", "numpy": "numpy"}
MODELS = Path.home() / ".cache" / "transcribe"
REL = "https://github.com/k2-fsa/sherpa-onnx/releases/download/"
SEG = MODELS / "sherpa-onnx-pyannote-segmentation-3-0" / "model.int8.onnx"
EMB = MODELS / "nemo_en_titanet_small.onnx"


# Pip-install missing Python packages
def ensure_deps():
    missing = [p for m, p in PKGS.items() if not importlib.util.find_spec(m)]
    if missing:
        subprocess.check_call([sys.executable, "-m", "pip", "install", *missing])


# Download diarization models if absent
def ensure_models():
    MODELS.mkdir(parents=True, exist_ok=True)
    if not SEG.exists():
        tar = MODELS / "seg.tar.bz2"
        urllib.request.urlretrieve(REL + "speaker-segmentation-models/sherpa-onnx-pyannote-segmentation-3-0.tar.bz2", tar)
        with tarfile.open(tar) as t:
            t.extractall(MODELS, filter="data")
        tar.unlink()
    if not EMB.exists():
        urllib.request.urlretrieve(REL + "speaker-recongition-models/nemo_en_titanet_small.onnx", EMB)


# Speaker turns (start, end, speaker) from 16 kHz mono audio
def diarize(audio, n_spk):
    import sherpa_onnx
    ensure_models()
    cfg = sherpa_onnx.OfflineSpeakerDiarizationConfig(
        segmentation=sherpa_onnx.OfflineSpeakerSegmentationModelConfig(
            pyannote=sherpa_onnx.OfflineSpeakerSegmentationPyannoteModelConfig(model=str(SEG))),
        embedding=sherpa_onnx.SpeakerEmbeddingExtractorConfig(model=str(EMB)),
        clustering=sherpa_onnx.FastClusteringConfig(num_clusters=n_spk, threshold=0.5),
        min_duration_on=0.3, min_duration_off=0.5)
    result = sherpa_onnx.OfflineSpeakerDiarization(cfg).process(audio).sort_by_start_time()
    return [(t.start, t.end, t.speaker) for t in result]


# Word-timestamped transcript (VAD skips silence; timeline preserved)
def words(audio, model):
    from faster_whisper import WhisperModel
    segs, _ = WhisperModel(model, device="cpu", compute_type="int8").transcribe(
        audio, vad_filter=True, word_timestamps=True, condition_on_previous_text=False, beam_size=5)
    return [w for s in segs for w in s.words]


# Speaker with max overlap for [a, b], else nearest turn
def speaker_of(a, b, turns):
    if not turns:
        return -1
    best = max(turns, key=lambda t: min(b, t[1]) - max(a, t[0]))
    if min(b, best[1]) - max(a, best[0]) > 0:
        return best[2]
    return min(turns, key=lambda t: min(abs(a - t[1]), abs(b - t[0])))[2]


# Merge consecutive same-speaker words into turns
def group(words, turns):
    out = []
    for w in words:
        s = speaker_of(w.start, w.end, turns)
        if out and out[-1]["speaker"] == s and w.start - out[-1]["end"] < 2.0:
            out[-1]["text"] += w.word
            out[-1]["end"] = w.end
        else:
            out.append({"speaker": s, "start": w.start, "end": w.end, "text": w.word})
    return renumber(out)


# Number speakers 1..N by first appearance; strip text
def renumber(out):
    order = {}
    for t in out:
        t["speaker"] = order.setdefault(t["speaker"], len(order) + 1)
        t["text"] = t["text"].strip()
    return out


# Seconds -> HH:MM:SS
def ts(x):
    return f"{int(x // 3600):02}:{int(x % 3600 // 60):02}:{int(x % 60):02}"


# Write <dst>.json and <dst>.md
def write(out, dst):
    dst.with_suffix(".json").write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
    dst.with_suffix(".md").write_text(
        "".join(f"[{ts(t['start'])}] Speaker {t['speaker']}: {t['text']}\n\n" for t in out), encoding="utf-8")
