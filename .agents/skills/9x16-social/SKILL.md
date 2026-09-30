---
name: 9x16-social
description: Convert a horizontal/landscape video into a 9:16 (1080×1920) vertical clip for social media (Instagram Reels, TikTok, YouTube Shorts). Use whenever the user asks for "social", "9:16", "vertical", "portrait", or to crop a video to a vertical slice. Supports crop cuts, glides (linear pans) and eased transitions at arbitrary times and x positions (px from the left). Probe the source first, translate the shot list into the renderer CLI, run it, report — the user verifies visually.
---

# 9:16 social clip conversion

Deep dives: `ai_docs/transitions.md` (types/formulas/gotchas), `ai_docs/timeline-hops.md` (chain mechanics), `ai_docs/conventions.md` (naming). Deterministic renderer: `scripts/render-9x16.sh` **in this skill dir — use relative paths from there**.

## Workflow

1. **Probe first** (never assume): `ffprobe` the source — width/height, fps,
   duration, audio streams, sample_aspect_ratio. Sources are read-only;
   every request renders a **new file** in `videos/`.
2. **Collect the shot list.** For each moment: crop **x in px from the left
   of the source**, the **transition type**, and **durations**. Defaults:
   `glide` D=0.1 s · `easeout` D=0.1 s, A=0.3 (crawl dial) · `cut` n/a.
   Times are original-timeline seconds. Between arrivals the camera HOLDS.
3. **Map to the CLI** (`scripts/render-9x16.sh`) — one `-m` per arrival,
   chronological, decimal seconds (convert `2:18` → `138`; `mm:ss.f` is
   accepted only by `-ss`/`-to`):

   ```
   render-9x16.sh -i videos/SRC.mp4 -o videos/NAME.mp4 \
     -ss 126 -to 149 -x0 0 \
     -m "138.5:440:easeout:4.5:0.3" \
     -m "145:90:easeout:3:0.3"
   ```

   | user says | `-m` entry |
   | --- | --- |
   | "cut to X at T" | `T:X:cut` |
   | "glide to X at T, 500 ms" | `T:X:glide:0.5` |
   | "ease out to X at T in D" | `T:X:easeout:D` (A=0.3 default) |
   | "smooth into X" / "not too slow at the end" | easeout (+ raise A if needed) |

   The script probes, computes the 9:16 slice (268×478 for 848×478 sources),
   builds the nested `if(lt(t,…))` chain, guards paren balance and X range
   (even, [0, W−268]), renders (libx264 crf 18 / aac 160k / faststart /
   lanczos), and structurally verifies. Add `-n` to dry-run the command.
4. **Report**: output path, the waypoints used, ffprobe numbers. Then the
   **user watches it** — never run pixel/PSNR checks (AGENTS.md rule 6).

## Naming

Descriptive `BASENAME_description[_N].mp4` — no number chains
(e.g. `tekes_full_glide_9.mp4`). Don't delete old renders; the user does.

## Reference renders (best-so-far)

- `videos/tekes_full_glide_9.mp4` — holds + easeout (A=0.3) moves, 2:06–2:29
- `videos/hareini_cut_smooth_2.mp4` — many glides at D=0.1