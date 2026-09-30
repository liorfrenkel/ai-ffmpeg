# Timeline hops — moving a crop position mid-clip

When the instruction wants the crop position to change *inside* the clip,
encode a piecewise function of time into the crop `x` (or `y`) with nested
conditional expressions:

```
if(lt(t, S1), X0, if(lt(t, S2), X1, if(lt(t, S3), X2, X3)))
```

Segments: position `X0` until second `S1`, `X1` from `S1`–`S2`, `X2` from
`S2`–`S3`, `X3` after `S3`. Any number of segments; every `X` must be even and
in-range.

## `t` is the ORIGINAL timeline — do not break this

`t` inside the expression equals the timestamp ffmpeg is *currently decoding*,
which is only the original timeline if `-i` appears **before** `-ss` (seek as
an output option):

```
ffmpeg -y -i "$SRC" -ss START -t DUR -vf "crop=$CW:$CH:'if(lt(t,$S1),$X0,…)':0,…" …
```

If `-ss` moves before `-i`, timestamps reset at the seek and `t` starts at 0 —
every hop time would be silently wrong. Keep `-i` first, always.

## Endpoints

- The last segment's position persists to the clip end (no closing condition).
- The first segment starts at the clip beginning (`START`); `lt(t, S1)` with
  `S1 = START` makes the first position apply for the whole clip.
- Hop boundaries are seconds of the original timeline; fractional values work
  too (`if(lt(t,16.5),…)`).

## Example

Clip from original 0:14, 11 s long; x = 110 until 0:16, 260 until 0:18,
back to 110:

```bash
ffmpeg -y -i "$SRC" -ss 14 -t 11 \
  -vf "crop=$CW:$CH:'if(lt(t,16),110,if(lt(t,18),260,110))':0,scale=1080:1920:flags=lanczos,format=yuv420p" \
  -c:v libx264 -crf 18 -preset medium -c:a aac -b:a 160k -movflags +faststart OUT.mp4
```

Verify each hop with `ai_docs/verification.md` (frame inside each segment +
frame straddling each switch).