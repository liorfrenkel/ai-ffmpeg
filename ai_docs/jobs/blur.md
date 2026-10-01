# Job: blurred background (9:16 blurred bars)

A horizontal (landscape) video sits centered in a taller 9:16 canvas, with a
blurred copy of the same video filling the bars above and below. The classic
social-post look for landscape content.

## Recipe (9:16, 1080×1920)

```bash
ffmpeg -y -i "$SRC" -filter_complex \
  "[0:v]split=2[bg][fg];\
   [bg]scale=$CW:$CH:force_original_aspect_ratio=increase:flags=lanczos, \
       crop=$CW:$CH,setsar=1,boxblur=25:2:10:2[bbg];\
   [fg]scale=$CW:-2:flags=lanczos,setsar=1,format=yuv420p[fgv];\
   [bbg][fgv]overlay=0:$Y,format=yuv420p[v]" \
  -map "[v]" -map 0:a -c:v libx264 -crf 18 -preset medium \
  -c:a aac -b:a 160k -movflags +faststart OUT.mp4
```

Two layers from one split of the source:

- **`[bg]`** — the *background*: source scaled to *fill* the canvas
  (`force_original_aspect_ratio=increase` → overshoots one axis), center-cropped
  to the canvas, then `boxblur` (luma r=25, chroma r=10; raise for softer,
  lower for sharper).
- **`[fg]`** — the *foreground*: source scaled to *fit the canvas width* and
  overlaid centered (vertical offset `Y`).

## Math

9:16 canvas is 0.5625× as wide as tall (`CW=1080`, `CH=1920`).

```
FH = round_even(H × CW / W)     # foreground height at width CW
Y  = round_even((CH − FH) / 2)  # vertical offset — the blur bar height
```

- Even `FH`/`Y` (H.264 + yuv420p). If `sample_aspect_ratio` ≠ 1:1, multiply W
  by it first.
- Example, 1920×1080 source → `FH=608`, `Y=656` → 656 px blur above/below.
- Horizontal source: `FH < CH` always, so blur bars exist. A portrait/near-square
  source breaks the premise (bars would be left/right) — tell the doc's user.

## Encoding

libx264, crf 18, preset medium, aac 160k, `+movflags +faststart`, lanczos.
Overrides only if the request explicitly asks.

## Naming & placement

Output next to the source, named per `ai_docs/conventions.md` —
`BASENAME_description[_N].mp4`, e.g. `animation_blur_1.mp4` (`description`
= `blur`). Iterate `_1`, `_2`, … when tuning bar height / blur strength.

## Done-criteria

- Output exists next to the source, named per conventions; source
  byte-identical (`shasum` if in doubt).
- `ffprobe`: `$CW`×`$CH`, fps matches source, duration == source, video + audio
  present.
- User verifies visually (AGENTS.md rule 6).