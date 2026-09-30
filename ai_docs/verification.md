# Verification — proving an edit correct without seeing pixels

## 1. Structural checks (always)

```bash
ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height,r_frame_rate,duration -of default=noprint_wrappers=1 "$OUT"
ffprobe -v error -show_entries stream=index,codec_type,codec_name -of default=noprint_wrappers=1 "$OUT"
```

Confirm every value the job requires: dimensions, fps, duration, streams
(audio present, codecs as specified). Expected values come from the job doc.

## 2. Pixel checks with PSNR (when pixels/geometry matter)

Render the same frame two ways and compare:

- **output frame** — frame at clip-relative second `k` of the rendered file;
- **reference frame** — frame from the source at the mapped original time,
  passed through the same filter graph (crop/scale) used for the render.

Mapping: a plain cut means clip second `k` = original `START+k`, where `START`
is the job's `-ss`. General rule: reference time = cut offset + clip time.

```bash
K=1                                # any whole second inside the clip
ORIG=$((START + K))
ffmpeg -y -v error -i "$OUT"    -ss "$K"                 -frames:v 1 /tmp/o.png
ffmpeg -y -v error -ss "$ORIG" -i "$SRC" \
  -vf "$REFERENCE_FILTER"                                 -frames:v 1 /tmp/r.png
ffmpeg -i /tmp/o.png -i /tmp/r.png -lavfi psnr -f null - 2>&1 | grep PSNR
```

| PSNR | Meaning |
| --- | --- |
| ≈ 35–45 dB | same pixels, geometry correct |
| < 15 dB | wrong geometry/position — rebuild and re-verify |
| in between | transcode noise — check a second frame before trusting |

## 3. Dynamic edits (moving crops, timed effects)

For anything whose geometry changes over time:

- one frame **inside each segment**, compared against that segment's static
  reference;
- one frame **straddling each switch** (e.g. at `S−ε` and `S+ε` around a hop
  boundary at second S) to confirm the change lands at the right time.

Prefer whole seconds (exact frames) where possible.

## Hygiene

- Scratch frames go in a temp dir (e.g. `/tmp/*_frames/`), recreated per run —
  never in the project directory.
- Verification numbers belong in the final report to the user, not in the repo.