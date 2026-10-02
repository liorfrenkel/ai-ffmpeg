# Variable frame rate (VFR) — detecting, mapping frames, cutting

When a source's frames don't fall on a single clean interval, "frame N" and
"second S" stop being interchangeable. This file is the shared reference;
job docs point here. CFR sources (`r_frame_rate` a clean ratio like `30/1`)
can skip straight to CFR rules at the bottom.

## Detecting VFR

```bash
ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate,avg_frame_rate,nb_frames -of default=noprint_wrappers=1 "$SRC"
```

- **CFR**: `r_frame_rate=30/1` and `avg_frame_rate=30/1` → every frame is
  exactly 1/30 s apart; frame ↔ time math below is exact.
- **VFR**: `avg_frame_rate` a non-clean ratio (e.g. `63240000/2152927` ≈
  29.374) → timestamps drift; never assume N/fps. Map each frame to its pts.

`nb_frames` is always reliable (frame 0 is the first frame; valid frame
args run 0 … nb_frames−1).

## Frame → original-timeline seconds (VFR)

Get the exact pts of any frame (0-based index `F` → row `F+1`):

```bash
ffprobe -v error -select_streams v:0 -show_entries frame=pts_time -of csv=p=0 "$SRC" \
  awk 'NR==F+1 {print}'          # pts of frame F
```

Use these pts as hop/cut boundaries in filters — the filter graph runs on
original timestamps (`-i` first). Around a cut point the cadence is usually
stable (frames can still be checked with a window like `NR>=F-2 && NR<=F+2`),
but the accumulated drift is real over long ranges — always take the mapped
value.

## Cutting by frame count (VFR)

Re-encode with a frame-index select + audio trim. `n` counts decoded frames,
so the boundary lands exactly regardless of timestamps:

```bash
ffmpeg -y -i "$SRC" \
  -vf "select='lt(n,F)',format=yuv420p" \
  -af "atrim=end=PTSoFF,asetpts=PTS-STARTPTS" \
  -c:v libx264 -crf 18 -preset medium -c:a aac -b:a 160k -movflags +faststart OUT.mp4
```

- `F` = exclusive last frame; `PTSoFF` = pts of frame `F` (audio can't be
  counted by `n` — it's a separate stream, so trim it by the time that ends
  the same range).
- Do **not** size the cut with `-t SECONDS` on VFR: a second counted from
  `avg_frame_rate` lands on a different frame than the one the user meant
  (e.g. 17.166 s of a ~29.374 fps stream ≈ 504 frames, not 515).

## CFR rules (clean r_frame_rate, e.g. 30/1)

- frame N ⇒ second N/fps exactly (`-ss 5.866667` = frame 176 of 30 fps).
- `-i "$SRC" -ss START -t DUR` + re-encode is frame-accurate even when START
  falls between keyframes.
- Cuts land on frame boundaries — report the frame-quantized duration, not
  the user's decimal.

**Both cases**: keep `-i` before `-ss` so filter times stay on the original
timeline (see `ai_docs/timeline-hops.md` for what breaks when you don't).