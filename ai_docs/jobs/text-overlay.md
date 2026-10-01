# Job: text overlay (static captions / titles)

Burn static text into a rendered clip — title, venue line, separator rule,
call-out. Handles **Hebrew (RTL) + mixed LTR/RTL** correctly.

## The gotcha — this ffmpeg has no text filters

Homebrew `ffmpeg 8.1.1` here is built **without** libfreetype/libass:
`drawtext`, `subtitles`, and `ass` all report `Unknown filter`. You cannot
render text inside ffmpeg. **→ render text to a transparent PNG with
`pango-view`, then composite with ffmpeg `overlay`.** Pango is a bonus here:
it does real bidi/shaping (HarfBuzz + FriBidi), which `drawtext` can't anyway.

Check availability before assuming:
`ffmpeg -h filter=drawtext` (→ `Unknown filter` = must use the PNG route).

## Recipe (pango → overlay)

Render **one PNG per line/block** (precise stacking), then overlay them all:

```bash
# 1. each text line ↑ transparent RGBA PNG
pango-view --pixels --background=transparent --foreground="#000000" \
  --font="Sans Bold 92" --no-display --output=/tmp/l1.png --text='ORANJOOZ'
pango-view --pixels --background=transparent --foreground="#000000" \
  --font="Sans 44" --no-display --output=/tmp/l2.png \
  --text='לבונטין 7 13.10 יום ג 20:00'
# ... l3 (rule), l4 ...

# 2. probe each PNG's width/height to compute the overlay x/y
# 3. stack them onto the clip, one overlay per line
ffmpeg -y -i BASE.mp4 -i /tmp/l1.png -i /tmp/l2.png ... \
  -filter_complex \
  "[0:v][1:v]overlay=x=X1:y=Y1[o1];[o1][2:v]overlay=x=X2:y=Y2[o2];...\
   ...format=yuv420p[v]" \
  -map "[v]" -map 0:a -c:v libx264 -crf 18 -preset medium \
  -c:a aac -b:a 160k -movflags +faststart OUT.mp4
```

## Layout math

Canvas `CW×CH`. For each line of measured width `w` and height `h`:

```
x = (CW − w) / 2          # horizontal center (int is fine for overlay x/y)
y = running vertical cursor, e.g. title at 120, then y += h + gap each line
```

Example (1080×1920 base, top-blur zone `0–656`), lines 541/542/596/431 wide,
heights 113/74/45/70:
`l1 y=120 · l2 y=263 · l3 y=365 · l4 y=435` (gaps ≈ 30/28/25).

## Pango syntax gotchas (session-proven)

- **Style before size:** `"Sans Bold 92"` ✓ — `"Sans 92 Bold"` ✗ silently
  falls back to a tiny default (~12 px) font.
- `--pixels` = sizes in px (dpi 72).
- Fonts: fontconfig resolves `Sans` per-script, including Hebrew fallback
  (a Hebrew-capable family like Arial is present). Verify with
  `fc-list :lang=he family`.
- Sub-total control: separate pango runs per line; one run per canvas shrinks
  the gap control.
- Separator rule: a `─` (U+2500) run of the desired width, or a `drawbox`
  line (drawbox needs no freetype; check it exists).

## Encoding

libx264, crf 18, preset medium, aac 160k, `+movflags +faststart`. Overlays are
RGBA PNGs composited by ffmpeg; the source video is never modified.

## Naming & placement

Output next to the source, named per `ai_docs/conventions.md` —
`BASENAME_description[_N].mp4`, e.g. `animation_text_1.mp4` (`description`
= `text`).

## Done-criteria

- Output exists next to the source; base render and sources byte-identical
  (`shasum` if in doubt).
- `ffprobe`: `CW`×`CH`, fps, duration == base, video + audio present.
- **User verifies visually** — RTL/Hebrew equivalence and legibility can't be
  pixel-checked; the operator confirms word order (AGENTS.md rule 6).