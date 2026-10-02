# Job: 1:1 square clip with moving crop window

Cut a time range of the source and render it as a square **1:1** clip
(1080×1080, or native square if the user says "don't scale"). The 1:1 window
sits centered horizontally and can **move vertically** over time (top / middle /
bottom, or an arbitrary even `y`) — easing in/out between positions, holding
between hops. Renderer then produces a **new file**.

The motion math / hop-chain mechanics come from `ai_docs/transitions.md`
(ease-out, glide, A dial) and `ai_docs/timeline-hops.md` (nested `if(lt(t,…))`
chains). This doc covers the 1:1-specific geometry, the frame→time mapping,
and the audio-fade trap.

## Recipe

```bash
ffmpeg -y -i "$SRC" -ss START -t DUR \
  -vf "crop=$CW:$CH:0:'$YEXPR',format=yuv420p" \
  -af "afade=t=out:st=$FADEST:d=1" \
  -c:v libx264 -crf 18 -preset medium -c:a aac -b:a 160k -movflags +faststart OUT.mp4
```

No scale filter unless the user explicitly wants a bigger square output
(1080×1080 for a 480-px-tall source is 2.25× upscale = soft, expected).

## Crop math (1:1)

Square window = **min(W, H) × min(W, H)**, anchored on the long axis:

```
CW = W ; CH = W          (W ≤ H: portrait source — vertical travel, x = 0)
CW = H ; CH = H          (H < W: wide source — horizontal travel, y = 0)
Y  ∈ [0, H−CH]   even    (portrait case; X analog for wide)
X  = 0                   (centered on the short axis)
```

1080×1920 → CH = 1080, Y range `[0, 840]`: **top 0, middle 420, bottom 840**.
Positions must be **even** (H.264 + yuv420p); round user numbers down, flag
the rounding. Multiply W by `sample_aspect_ratio` first if ≠ 1:1.

## Frame→time mapping

Cuts/hops may be given as frame numbers — but whether N/fps works depends on
whether the source is CFR or VFR. **Always check `r_frame_rate`/`avg_frame_rate`
first** (`ffprobe -show_entries stream=r_frame_rate,avg_frame_rate`).

- **CFR** (clean ratio, e.g. `30/1`): frame N = N/fps exactly; `-ss`/`-t`
  seconds cut frame-exactly on their own.
- **VFR** (drifted avg, e.g. `63240000/2152927`): map every hop frame to its
  exact pts (`ai_docs/vfr.md`) and cut by frame index
  (`select='lt(n,F)'` + `atrim`) — never `-t` seconds.

## Timeline traps (these bit us — read twice)

1. **`-ss` goes AFTER `-i`.** `-ss` before `-i` resets timestamps, `t` starts
   at 0, and every hop time in the crop expression is silently wrong (the
   ease-out landed ~6 s late in real life). `-i "$SRC" -ss START -t DUR` —
   never the other way around.
2. **`afade st=` is original-timeline too, not clip-relative.** With `-ss`
   after `-i`, the *whole* filter graph (video AND audio) runs on original
   timestamps. A "fade in the last second" is NOT `st = DUR − 1`; it is
   `st = (START + DUR) − 1`. On a clip START 5.8667 / DUR 24.1333, the fade
   must be `st=29` (original 29.0–30.0) — `st=23.13` fired ~6 s early, right
   at the start of the clip.
3. **Left of the clip, hold.** First segment holds its initial `y`; last
   segment persists to clip end. Hop boundaries are original-timeline seconds
   (fractional OK).

## Ease-out motion (A = 0.3, per transitions doc)

`y(t) = Y0 + (Y1−Y0)·(0.3·r + 0.7·(1−(1−r)²))`, `r = (t−(T−D))/D`.
Chain hops earliest-outermost; every anchor (`Y0`, `Y1`) even and in range.

## Encoding

libx264, crf 18, preset medium, aac 160k, `+movflags +faststart`. No scale =
native square resolution. Override only if the request explicitly asks.

## Naming & placement

Output next to the source, per `ai_docs/conventions.md` —
`BASENAME_1x1_description[_N].mp4`; bump `_N` on iterations of the same edit
(`ron_chen_wild_dance_tune_1x1_topmid_176_900_fade_4`). Add the cut range or
`fade` / `ease` to the description when it matters to the user. Scratch frames
→ `/tmp/*_frames/`.

## Done-criteria

- Output exists next to the source, named per conventions; source
  byte-identical.
- `ffprobe`: square (W×W), source fps, frame count == requested, audio present.
- Fade end verified with `astats` (loud before `FADEST`, quiet after
  `FADEST+1`) — audio checks are allowed; **no pixel checks** on the render
  (AGENTS.md rule 6).
- User watches for motion feel (ease timing/A dial) and confirms visually.