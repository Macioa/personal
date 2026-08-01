# Demo Video Recording

> AVOID HALLUCINATIONS, GUESSWORK, PARAPHRASING
> USE DIRECTLY QUOTED INFORMATION IN ALL TASKS
> REVIEW ATOMIC.MD FOR OPERATIONAL INSTRUCTIONS

Scripted UI walkthrough → MP4 with a synthetic cursor.

**Local paths:** read `local.env` at the repo root (copy from `local.env.example` if missing). Use `PLAYWRIGHT_DIR`, `DEMO_VIDEOS_DIR`, `VIDEO_OUTPUT_DIR`, `DEMO_RECORD_SCRIPT`, `E2E_DIR`. Do not invent values.

## Purpose & style (marketing / ad material)

These are **ad creatives**, not tutorials. Every scene should be:

- **Direct to purpose** — show the one feature, no filler. Land on the payoff fast; cut setup that isn't the point.
- **Short** — tight clip (a few seconds); trim dead time and long waits.
- **Almost-instant typing** — type fast (`pressSequentially(text, { delay: 8 })` or prefer `locator.fill(text)` for form fields). No slow keystroke-by-keystroke.
- **Minimal scrolling** — avoid unnecessary scrolling; jump/`scrollIntoView` to the element that matters. A quick reveal beats a slow pan.

## Stack

- Playwright (`@playwright/test`) — records WebM.
- ffmpeg (`Gyan.FFmpeg` via winget) — WebM → MP4.

## 1. Explore & document

- Pick a no-auth flow with forms + navigation.
- Reuse selectors from `$E2E_DIR` under `$PLAYWRIGHT_DIR`.
- Confirm pages return 200: `curl -s -o /dev/null -w "%{http_code}" <url>`.
- Record per step: URL, selectors, button names, a `waitFor` anchor.

## 2. Generate

- Script inside `$PLAYWRIGHT_DIR`; video output outside (scratchpad / `$DEMO_VIDEOS_DIR` as configured).
- Move: `page.mouse.move(x, y, { steps: 30 })`. Type fast: `pressSequentially(text, { delay: 8 })`, or `locator.fill(text)` for form fields (see Purpose & style).
- Gate optional clicks: `if (await locator.count())`.
- Keep scenes tight — minimal scrolling, short dwells, cut to the payoff.

## Cursor

`context.addInitScript(...)`: draw a DOM element on `mousemove`, ripple on `mousedown`.

## Record

```js
const context = await browser.newContext({
  viewport: { width: 1280, height: 800 },
  recordVideo: { dir: OUT_DIR, size: { width: 1280, height: 800 } },
});
// drive page
await page.close();
const p = await page.video().path();
await context.close();
```

## Timeouts & run length

- **Per-action timeout** via `RECORD_TIMEOUT_MS` (default 20000). Sets Playwright's default wait/click/navigation timeout — bump on slow machines or heavy pages: `RECORD_TIMEOUT_MS=45000 node $DEMO_RECORD_SCRIPT A6 A7` (run from `$PLAYWRIGHT_DIR`).
- **Generous wall-clock timeout.** Promo encode uses motion interpolation (`minterpolate`), ~2–4 min per scene on top of record time — multi-scene runs can take 15–30+ min. Run in background (or long tool timeout) so it isn't killed mid-render. Use `FAST=1` to skip interpolation for quick selector/visual validation first.

## Convert

Playwright records WebM (VP8); transcode to H.264 MP4 with **ffmpeg**. Promo assets — optimize for quality.

- **ffmpeg source:** official Gyan.dev build (`winget install Gyan.FFmpeg`). Playwright's bundled ffmpeg is webm-only — no H.264/mp4 muxer. If full ffmpeg isn't on PATH, drop `ffmpeg.exe` in `~/bin` (already on PATH) — no admin needed.
- **Frame rate → 60 fps, motion-compensated.** Playwright screencast is ~25 fps; plain `-r 60` duplicates frames (still choppy). Use `minterpolate` (mci) for real intermediate frames — smooth cursor and scrolling.
- **Encode quality:** `-crf 18 -preset slow -profile:v high` (near-visually-lossless).
- **Capture crispness:** record at 1920×1080 with `deviceScaleFactor: 2` so the page renders at 2× and downsamples (supersampling) — sharp text/edges.
- **Smooth scrolling:** in-page rAF ease (`window.scrollTo`), not stepped `mouse.wheel` — stepping looked choppy.

```bash
ffmpeg -y -i in.webm \
  -vf "minterpolate=fps=60:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1" \
  -c:v libx264 -preset slow -crf 18 -profile:v high -pix_fmt yuv420p \
  -movflags +faststart out.mp4
```

Write final to `$VIDEO_OUTPUT_DIR`.
