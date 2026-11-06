"""Speaker-labeled transcript turns -> overlapping search chunks (pure, no I/O).

Turns: [{speaker, start, end, text, words?: [[start, end], ...]}] (scripts/transcribe output).
Dry run: python chunk.py <transcript.json> [...]
"""
import json, re, sys
from collections import Counter
from dataclasses import dataclass, replace
from math import inf
from pathlib import Path

# Sizes tuned on temp/transcripts (10 paraphrased queries, vector only): 80/120/25 put the
# right chunk in the top 3 for 8/10 vs 5/10 at 200/300/40; dropping overlap cost 2.
VERSION = 1
MERGE_GAP = 5.0   # s: rejoin same-speaker turns split by diarization
MAX_UTT = 120     # words: split longer utterances at sentence ends (p95 turn = 107)
TARGET = 80       # words: preferred chunk size
MIN = 40          # words: smaller tail merges into previous chunk
MAX = 120         # words: hard cap (also capped by model tokens, see chunk())
OVERLAP = 25      # words carried into next chunk
TOPIC_GAP = 20.0  # s silence: boundary once chunk >= MIN
HARD_GAP = 60.0   # s silence (holds): forced boundary, no overlap
ISOLATED = 20.0   # s silence on both sides of a hallucinated phrase
SILENCE_PHRASES = {"thank you", "thanks for watching", "you", "bye"}  # whisper output on silence
SENT = re.compile(r"(?<=[.?!])\s+")
LABEL = re.compile(r"^\[\d\d:\d\d:\d\d\] ([^:\n]+):", re.M)


@dataclass
class Utt:
    speaker: int
    start: float
    end: float
    text: str
    wt: list   # start time per word (exact or interpolated)
    tn: list   # turn_no per word
    carried: bool = False  # overlap copy from previous chunk


@dataclass
class Chunk:
    chunk_no: int
    start: float
    end: float
    first_turn: int
    last_turn: int
    speakers: list
    words: int
    content: str


# Word count
def n(s):
    return len(s.split())


# Per-word start times: exact from turn["words"] if counts match, else linear over [start, end]
def word_times(t):
    k = n(t["text"])
    w = t.get("words")
    if w and len(w) == k:
        return [x[0] for x in w]
    return [t["start"] + (t["end"] - t["start"]) * i / max(k, 1) for i in range(k)]


# Drop whisper silence hallucinations: isolated <=3-word turn that is a known phrase or repeats >=3x
def drop_hallucinations(turns):
    key = lambda t: t["text"].lower().strip(" .,!?")
    seen = Counter(key(t) for t in turns if n(t["text"]) <= 3)
    out = []
    for i, t in enumerate(turns):
        gap_prev = t["start"] - turns[i - 1]["end"] if i else inf
        gap_next = turns[i + 1]["start"] - t["end"] if i + 1 < len(turns) else inf
        short = n(t["text"]) <= 3 and min(gap_prev, gap_next) >= ISOLATED
        if short and (key(t) in SILENCE_PHRASES or seen[key(t)] >= 3):
            continue
        if t["text"].strip():
            out.append(t)
    return out


# Merge consecutive same-speaker turns (gap < MERGE_GAP) into utterances
def utterances(turns):
    out = []
    for i, t in enumerate(turns):
        u = out[-1] if out else None
        wt = word_times(t)
        if u and u.speaker == t["speaker"] and t["start"] - u.end < MERGE_GAP:
            u.text += " " + t["text"]
            u.end = t["end"]
            u.wt += wt
            u.tn += [i] * len(wt)
        else:
            out.append(Utt(t["speaker"], t["start"], t["end"], t["text"], wt, [i] * len(wt)))
    return out


# Split text into <=size-word pieces at sentence ends; overlong sentences cut every `size` words
def pieces(text, size):
    out, cur = [], []
    for s in SENT.split(text):
        w = s.split()
        for j in range(0, len(w), size):
            part = w[j:j + size]
            if cur and len(cur) + len(part) > size:
                out.append(cur)
                cur = []
            cur += part
    return [" ".join(p) for p in out + [cur] if p]


# Sub-utterance for words [a, b), timestamps and turns from per-word lists
def sub(u, a, b, text):
    end = u.wt[b] if b < len(u.wt) else u.end
    return replace(u, start=u.wt[a], end=end, text=text, wt=u.wt[a:b], tn=u.tn[a:b])


# Split utterances over MAX_UTT words
def split_long(utts):
    out = []
    for u in utts:
        if n(u.text) <= MAX_UTT:
            out.append(u)
            continue
        off = 0
        for p in pieces(u.text, MAX_UTT):
            out.append(sub(u, off, off + n(p), p))
            off += n(p)
    return out


# Overlap seed: last utterance if <= OVERLAP words, else its trailing sentences <= OVERLAP words
def tail(chunk):
    u = chunk[-1]
    if n(u.text) <= OVERLAP:
        return [replace(u, carried=True)]
    keep = []
    for s in reversed(SENT.split(u.text)):
        if n(" ".join([s] + keep)) > OVERLAP:
            break
        keep.insert(0, s)
    if not keep:
        return []
    k, total = n(" ".join(keep)), n(u.text)
    return [replace(sub(u, total - k, total, " ".join(keep)), carried=True)]


# Words in a chunk, excluding carried overlap
def fresh(chunk):
    return sum(n(u.text) for u in chunk if not u.carried)


# Total words in a chunk
def size(chunk):
    return sum(n(u.text) for u in chunk)


# Group utterances into chunks; fits(chunk, slack) enforces the size cap
def pack(utts, fits):
    chunks, cur = [], []
    for u in utts:
        gap = u.start - cur[-1].end if cur else 0
        held = gap >= HARD_GAP and fresh(cur) >= MIN  # tiny lead-in ("Oh,") rides across a hold
        hard = bool(cur) and (held or not fits(cur + [u]))
        soft = bool(cur) and size(cur) >= TARGET and u.speaker != cur[-1].speaker \
            and not cur[-1].text.rstrip().endswith("?")  # keep a question with its answer
        topic = bool(cur) and size(cur) >= MIN and gap >= TOPIC_GAP
        if hard or soft or topic:
            chunks.append(cur)
            cur = tail(cur) if gap < HARD_GAP else []
            if not fits(cur + [u], OVERLAP):
                cur = []  # carried overlap may exceed MAX by up to OVERLAP (keeps Q with A)
        cur.append(u)
    if cur:
        chunks.append(cur)
    if len(chunks) > 1 and fresh(chunks[-1]) < MIN:
        last = chunks.pop()
        new = [u for u in last if not u.carried]
        if fits(chunks[-1] + new):
            chunks[-1] += new
        else:
            chunks.append(last)
    return chunks


# "Label: text" lines; consecutive same-speaker pieces joined
def render(chunk, labels):
    lines = []
    for u in chunk:
        if lines and lines[-1][0] == u.speaker:
            lines[-1][1].append(u.text)
        else:
            lines.append((u.speaker, [u.text]))
    return "\n".join(f"{labels.get(s, f'Speaker {s}')}: {' '.join(t)}" for s, t in lines)


# Filtered turns -> Chunk list. tokens(text) + budget: also cap rendered chunk tokens
# (label-heavy calls with many short turns hit the model limit before MAX words)
def chunk(turns, labels, tokens=None, budget=None):
    fits = lambda c, slack=0: size(c) <= MAX + slack and (tokens is None or tokens(render(c, labels)) <= budget)
    out = []
    for i, c in enumerate(pack(split_long(utterances(turns)), fits)):
        out.append(Chunk(i, c[0].start, c[-1].end, c[0].tn[0], c[-1].tn[-1],
                         sorted({u.speaker for u in c}), size(c), render(c, labels)))
    return out


# speaker_no -> label from sibling .md ([HH:MM:SS] Label: text, one line per raw JSON turn)
def md_labels(raw, md_path):
    if not md_path.exists():
        return {}
    labels = LABEL.findall(md_path.read_text(encoding="utf-8"))
    if len(labels) != len(raw):
        sys.exit(f"{md_path}: {len(labels)} labeled lines != {len(raw)} JSON turns")
    out = {}
    for t, l in zip(raw, labels):
        if out.setdefault(t["speaker"], l.strip()) != l.strip():
            sys.exit(f"{md_path}: speaker {t['speaker']} has labels {out[t['speaker']]!r} and {l!r}")
    return out


# Seconds -> HH:MM:SS
def ts(x):
    return f"{int(x // 3600):02}:{int(x % 3600 // 60):02}:{int(x % 60):02}"


# Print chunk boundaries for each JSON file
def dry_run(paths):
    for p in map(Path, paths):
        raw = json.loads(p.read_text(encoding="utf-8"))
        turns = drop_hallucinations(raw)
        chunks = chunk(turns, md_labels(raw, p.with_suffix(".md")))
        print(f"== {p.name}: {len(raw)} turns, {len(turns)} kept, {len(chunks)} chunks")
        for c in chunks:
            first = c.content.splitlines()[0][:90]
            print(f"  {c.chunk_no:3} [{ts(c.start)}-{ts(c.end)}] t{c.first_turn}-{c.last_turn} {c.words:3}w  {first}")


if __name__ == "__main__":
    dry_run(sys.argv[1:])
