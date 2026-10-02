# Job: simple cut (trim a range, keep geometry)

Trim the source to a time range and render a **new file** with the exact
same resolution / fps — no crop, no resize. Uses re-encode (not stream
copy) so the cut is frame-accurate even when `START` falls between
keyframes (stream copy would snap to the previous I-frame).

## Recipe

```bash
ffmpeg -y -ss "$START" -i "$SRC" -t "$DUR" \
  -vf "format=yuv420p" \
  -c:v libx264 -crf 18 -preset medium -c:a aac -b:a 160k -movflags +faststart OUT.mp4
```

- `START` / `DUR` = original-timeline seconds (`DUR = duration − START`;
  read `duration` with `ffprobe` first).
- `-ss` **before** `-i` + re-encode: ffmpeg decodes from the previous
  keyframe and discards up to `START` → frame-accurate, and faster than
  `-ss` after `-i`.
- Geometry is carried over untouched; `format=yuv420p` only normalizes
  pixel format for the encoder.
- **Cuts land on frame boundaries.** `-t`/`-to` round to the nearest output
  frame (30 fps → 33.3 ms steps): 38.85 s end cut rendered 14.37 s
  (431 frames), not 14.35 s. Report the frame-quantized duration, not the
  user's decimal.
- **VFR source?** (check `ffprobe`: `r_frame_rate` vs `avg_frame_rate`):
  frame numbers ≠ seconds — map frames to pts and cut by frame index per
  `ai_docs/vfr.md`.

## Crop math

None — source geometry is kept as-is.

## Encoding

libx264, crf 18, preset medium, aac 160k, `+movflags +faststart`. Override
only if the request explicitly asks.

## Naming & placement

Output next to the source, named per `ai_docs/conventions.md` —
`BASENAME_description[_N].mp4` with a short description of the edit
(e.g. `lo_era_ra_zman_le_ot_cut_37.mp4`).

## Done-criteria

- Output exists next to the source, named per conventions; source
  byte-identical (`shasum` if in doubt).
- `ffprobe`: width×height == source, duration == `DUR` (± one frame),
  video + audio streams present.