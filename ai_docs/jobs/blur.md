# Job: blurred background (9:16 blurred bars)

A horizontal (landscape) video sits centered in a taller 9:16 canvas, with a
blurred copy of the same video filling the bars above and below. The classic
social-post look for landscape content.

## Recipe (9:16, 1080×1920) — the "real blur" chain

```bash
ffmpeg -y -i "$SRC" -filter_complex \
  "[0:v]split=2[bg][fg];\
   [bg]scale=$CRUSH_W:$CRUSH_H:force_original_aspect_ratio=increase:flags=area, \
       crop=$CRUSH_W:$CRUSH_H,gblur=sigma=$SIGMA_SMALL, \
       scale=$CW:$CH:flags=area,gblur=sigma=$SIGMA_BIG, eq=<$MAP> ,setsar=1[bbg];\
   [fg]scale=$CW:-2:flags=lanczos,setsar=1,format=yuv420p[fgv];\
   [bbg][fgv]overlay=0:$Y,format=yuv420p[v]" \
  -map "[v]" -map 0:a -c:v libx264 -crf 18 -preset medium \
  -c:a aac -b:a 160k -movflags +faststart OUT.mp4
```

Two layers from one split of the source:

- **`[bg]`** — the *background*. The order matters (see "How to blur properly"):
  1. crush to a tiny frame (`$CRUSH_W`×`$CRUSH_H`, see dials),
  2. heavy gaussian **on the small frame** (`gblur=sigma=$SIGMA_SMALL`),
  3. upscale to the canvas (`flags=area` = averaging, not sharp lanczos),
  4. light gaussian at full res (`gblur=sigma=$SIGMA_BIG`) to melt the
     interpolation grid,
  5. optional `eq=` for the brightness variant.
- **`[fg]`** — the *foreground*: source scaled to *fit the canvas width* and
  overlaid centered (vertical offset `Y`), **no blur, no eq**.

## How to blur properly (hard-won, session-proven)

Goal: the background must *never take attention* — no recognizable figures,
silhouettes, or edges. Lessons from iterating `animation_blur_1…11`:

1. **Plain blur is not enough.** `boxblur=25:2` (or any single-frame blur at
   full res) leaves recognizable dark shapes from the source — they read as
   ghost figures. Users will say "I can still see figures" even at r=40–50.
2. **Blur the small frame, not the big one.** Running `gblur` at full res with
   a huge σ is slow *and* weak (finite kernel). Instead crush the frame first
   and gaussian it there: σ=8 on a 72×128 frame ≈ σ≈100 at 1080×1920, at a
   fraction of the cost. This is the single most effective step.
3. **Crush size = detail floor.** Smaller crush → flatter wash:
   - `270×480` — smooth but motion still reads
   - `135×240` — figures gone, spatial color blobs remain
   - `108×192` — near-flat, only slow palette breathing
   - `72×128` — structureless dark wash (the `_10/_11` default)
   Users perceive "not blurred enough" even at `_9` (108×192 + σ40 full-res) —
   the jump to `_10` (72×128 + small-frame σ8) finally landed.
4. **Crush the contrast, not the brightness.** After blur, kill leftover edges
   with `eq=…:contrast=0.55` (0.75 = mild, 0.55 = flat). Users conflate
   "transparent / less noticeable" with alpha — what they want is detail
   destruction; contrast reduction + de-saturation delivers it.
5. **Don't blur fit-bars — blur the fill.** Blur the `force_original_aspect_
   _ratio=increase` fill (zoomed past the frame), never the foreground video.

## Brightness variants

Same blur chain, different `eq=` map for the background tone:

| variant | `eq` map | notes |
| --- | --- | --- |
| **light** (natural) | *(omit eq)* | `animation_blur_2`, `_11` — bright, matches source palette |
| **dark** | `brightness=-0.35:saturation=0.7:contrast=0.85` | `animation_blur_7` — dims white sources so bars don't glare |
| **deeper dark** | `brightness=-0.4:saturation=0.4:contrast=0.55` | `animation_blur_10` — moody, near-formed contrast killed |

White/solid-background sources glare in the light variant — that's when a dark
variant is a strict improvement (users chose dark, then a light remix).

## Dials (defaults = `_10` family)

```
CRUSH_W=72  CRUSH_H=128          # detail floor (108×192 = near-flat)
SIGMA_SMALL=8                    # σ on the small frame (≈σ100 at full res)
SIGMA_BIG=12                     # melts upscale interpolation blocks
eq= omitted or dark map above     # see Brightness variants
FH / Y: see Math below
```

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

libx264, crf 18, preset medium, aac 160k, `+movflags +faststart`. `flags=area`
on both bg scales (unspecified-downscale picks area-like anyway; upscale must
be `area` — NOT lanczos — or the hard blur softens back into squares).
Overrides only if the request explicitly asks.

## Naming & placement

Output next to the source, named per `ai_docs/conventions.md` —
`BASENAME_description[_N].mp4`, e.g. `animation_blur_7.mp4` (`description`
= `blur`). Iterate `_1`, `_2`, … when tuning blur strength / brightness —
keep every render; users pick a winner from the ramp.

## Done-criteria

- Output exists next to the source, named per conventions; source
  byte-identical (`shasum` if in doubt).
- `ffprobe`: `$CW`×`$CH`, fps matches source, duration == source, video + audio
  present.
- User verifies visually (AGENTS.md rule 6).