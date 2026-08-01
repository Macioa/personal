# Daily Deliverables Video

> AVOID HALLUCINATIONS, GUESSWORK, PARAPHRASING
> USE DIRECTLY QUOTED INFORMATION IN ALL TASKS
> REVIEW ATOMIC.MD FOR OPERATIONAL INSTRUCTIONS

Turn a single developer's merged/closed/open PRs from a day into one narrated, under-5-minute "here's what I shipped" report video.

**Local paths:** read `local.env` at the repo root (copy from `local.env.example` if missing). Use `PLAYWRIGHT_DIR`, `DEMO_VIDEOS_DIR`, `VIDEO_OUTPUT_DIR`. Do not invent values.

This is the **orchestration layer**. Low-level recording + encoding (Playwright synthetic-cursor capture, 1920×1080 @ dsf 2, WebM→H.264, 60fps `minterpolate`, smooth rAF scroll, capture crispness) lives in `[demo-video.md](../skills/demo-video.md)` — **do not duplicate it here; follow it for capture or transcode.** This doc covers only what that skill doesn't: choosing content, framing as a daily report, on-screen text, voiceover, length budget, and stitching.

Reusable pipeline in `$DEMO_VIDEOS_DIR`:

| File | Role |
|------|------|
| `scenes.mjs` | Ordered storyboard: `slate` (text-only) and `site` (recorded) scenes + narration hooks |
| `overlay.mjs` | On-screen text — title cards + lower-third captions, smooth scroll, consent dismiss (injected via `addInitScript`) |
| `cursor-init.mjs` | Synthetic cursor + click ripple (see `demo-video.md`) |
| `record.mjs` | Drives Playwright per scene → one WebM each. Resolves `@playwright/test` from `$PLAYWRIGHT_DIR` (or env `PLAYWRIGHT_DIR`) |
| `convert.mjs` | WebM → MP4. `FAST=1` = quick validation; unset = quality `minterpolate` pass (recipe per `demo-video.md`) |
| `voiceover.mjs` | Free neural narration (`edge-tts`), one line per scene, fit to each scene's exact duration, muxed on |
| `splice.mjs` | Concatenate per-scene MP4s → final video in `$VIDEO_OUTPUT_DIR` |

**Tools required:** `node`, `gh` (GitHub CLI), `ffmpeg`/`ffprobe` on PATH (Gyan build — see `demo-video.md`), Playwright browsers (installed in `$PLAYWRIGHT_DIR`), and `python -m pip install edge-tts` for voiceover. `edge-tts` is free, needs no API key, but needs internet.

---

## Step 1 — Triage the day's PRs (delivery-focused)

Goal: decide **what a viewer should see shipped**, not a changelog. Pick the user-facing payoff of each PR and rank by impact.

1. **List the developer's PRs** for the target day(s) — include open, merged, and closed (closed/superseded and still-open can both be deliverables worth narrating):
   ```bash
   gh pr list --author <github-login> --state all --limit 40 \
     --json number,title,state,createdAt,mergedAt,closedAt,headRefName \
     --jq '.[] | "\(.number)\t\(.state)\t\(.createdAt)\t\(.title)"'
   ```
   Keep rows whose `createdAt`/`mergedAt` fall on today or yesterday (or the asked window).

2. **Read each PR's notes** for the *deliverable*, not the diff:
   ```bash
   gh pr view <n> --json title,state,body,files
   ```
   Mine **Summary / What / Why / How** for the one user-visible outcome. The files list shows where it surfaces (route, page, component) for camera targeting.

3. **Classify coverage** for each deliverable:
   - **Record** — publicly reachable and safe to show. Prefer **production** if the feature is live there (real content/assets, zero local setup); otherwise stand up locally. Capture itself is `demo-video.md`'s job.
   - **Describe-only (text slate, no footage)** — must not or cannot show: **in-review / unmerged**, **auth-gated** UI (never enter credentials), or **sensitive** features. Say plainly on the slate + in narration that it's described, not shown.

4. **Honor user-specified priorities.** Named priorities ("lead with X", "make sure Y is covered", "don't record Z") override impact ranking and dictate scene order and time budget. Record any "describe but don't show" as a describe-only slate.

Deliverable of this step: ordered scenes, each tagged record vs describe-only, with the one-line "what shipped" for each.

---

## Step 2 — Structure & length budget

**Hard cap: 5:00. Aim ≤ 4:50.** Short and delivery-focused — land each payoff fast, cut setup (see `demo-video.md` "Purpose & style").

Standard structure (encoded in `scenes.mjs`):

```
intro slate  →  [priority deliverables, highest-impact first]  →
                [secondary "also shipped" deliverables]  →  outro slate
```

- Weight time toward the user's priorities — top priority may own most of the runtime.
- Give each scene a dwell cap in `scenes.mjs`. After the fast pass, measure and trim: `ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 <mp4>`. Sum per-scene durations; if over 4:50, trim the longest secondary scene first, then per-scene dwells — never drop a stated priority.

---

## Step 3 — On-screen text (title cards + captions)

All text is rendered natively by `overlay.mjs` (no burn-in step) — crisp at full res and theme-consistent:

- **Title card** — full-screen branded slate opening each scene. For a `site` scene it raises the instant the page commits and masks the load, then reveals the settled page (`h.open(url, {eyebrow, heading, body, hold})`). For describe-only, the slate *is* the whole scene (`kind: "slate"` — no site footage).
- **Lower-third caption** — short label pinned bottom-left during footage (`h.caption("…")` / `h.clearCaption()`), naming what's on screen as the cursor moves.
- Keep headings ~3–6 words, captions one line. Text from triage "what shipped" lines, tightened.

---

## Step 4 — Record & encode

Capture and transcode are **fully covered by `demo-video.md`** — follow it for capture settings, synthetic cursor, `minterpolate` ffmpeg recipe, and `RECORD_TIMEOUT_MS` / wall-clock guidance. In this pipeline:

- `record.mjs` produces one WebM per scene.
- `convert.mjs` transcodes: run **`FAST=1`** first to validate selectors, overlays, and framing (spot-check frames with `ffmpeg -ss <t> -i … -frames:v 1 out.png`); then run **without `FAST`** for the quality, motion-interpolated encode. Quality is slow (minterpolate well over real-time per scene) — run in background. If the user wants it fast, ship the `FAST=1` encode; clean, just slightly less buttery cursor/scroll motion.

---

## Step 5 — Voiceover (free)

Narration uses **Microsoft Edge neural TTS via `edge-tts`** — free, no key, natural voices (offline fallback: Windows SAPI, but robotic). `voiceover.mjs`:

- Holds one narration line per scene id in its `NARRATION` map.
- Synthesizes each line, then fits it to that scene's **exact** video duration (silence lead-in + pad; only speeds a line slightly if it would overrun), so audio stays in sync.
- Concatenates per-scene tracks and muxes AAC onto the video (video stream copied, not re-encoded).

Run / tune:
```bash
cd "$DEMO_VIDEOS_DIR"
node voiceover.mjs                                  # default voice
EDGE_VOICE=en-US-BrianNeural node voiceover.mjs     # casual male
EDGE_VOICE=en-US-AriaNeural  node voiceover.mjs     # female
EDGE_RATE=+15% node voiceover.mjs                   # brisker
```
Default voice: `en-US-AndrewNeural` (warm, confident) at `+10%`. Write narration lines to sit just under each scene's length; verify the muxed result is non-silent and matches the video length:
```bash
ffprobe -v error -show_entries stream=codec_type,duration -of csv=p=0 <out.mp4>
ffmpeg -hide_banner -i <out.mp4> -af volumedetect -f null - 2>&1 | grep mean_volume
```

---

## Framing & narration rules (REQUIRED)

This video is a **daily report for one developer** — first person, their work.

- **Name the developer in the video.** Intro slate shows the developer's name (and the date); outro can too.
- **The opening narration line must be exactly:**
  > "Here's a summary of my deliverables for **[today's date]**."

  Resolve `[today's date]` to the actual date (e.g. "July 21st, 2026") — never leave the placeholder. First thing spoken, over the intro slate.
- **Voice throughout is first-person and delivery-focused** — "I shipped…", "I added…", "Still in review:…". State what was delivered and where it shows up; skip implementation detail unless it *is* the deliverable.
- Keep it plain and confident — no hype, no filler. One clear sentence per beat.

---

## Guardrails

- Production is navigated **read-only**: page loads, scrolls, safe in-page clicks (filters, client-side seeks). **No** form submits, CTA/booking clicks, or account changes.
- **Never enter credentials** into any login field. Auth-gated UI is describe-only.
- **Never record** in-review/unmerged or sensitive features — describe them on a slate and say so.
- Dismiss cookie/consent banners with the privacy-preserving choice (`overlay.mjs` does this best-effort).

---

## End-to-end run

```bash
cd "$DEMO_VIDEOS_DIR"

# 1. (after editing scenes.mjs + voiceover.mjs NARRATION for the day)
node record.mjs                 # all scenes → scratchpad/webm

# 2. validate fast, spot-check frames, confirm total < 4:50
FAST=1 node convert.mjs

# 3. quality encode (background — slow) OR keep the FAST encode
node convert.mjs

# 4. stitch → $VIDEO_OUTPUT_DIR/daily-summary-<date>.mp4
node splice.mjs

# 5. add narration → …-narrated.mp4
node voiceover.mjs
```

Final deliverable: `$VIDEO_OUTPUT_DIR/daily-summary-<date>-narrated.mp4` — one video, < 5:00, developer named, opening line as specified above.

## Per-run checklist

- [ ] PRs for the day triaged; each deliverable tagged record vs describe-only
- [ ] User priorities reflected in scene order + time budget
- [ ] In-review / auth-gated / sensitive items are describe-only (no footage)
- [ ] Total runtime < 5:00 (verified with ffprobe)
- [ ] Developer's name on screen; opening line "Here's a summary of my deliverables for [today's date]"
- [ ] Narrated output verified non-silent and length-matched to the video
