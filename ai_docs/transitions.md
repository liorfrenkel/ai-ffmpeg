# Transitions — types, recipes, gotchas

Canonical reference for crop-position transitions (vocabulary → exact recipe).
Chain mechanics (nested `if(lt(t,…))`, seek rules): `ai_docs/timeline-hops.md`.

## Ground rules

- Times are **original-timeline seconds** — `-i` first, `-ss` after, so `t` in
  the crop expression is the original timeline. Never break this.
- `x` = px **from the left of the source frame**; even, in `[0, W−CW]`
  (848×478 source → slice 268 wide, range `[0, 580]`).
- Between transitions the crop **holds** its position; clips end on a hold.
- Multi-transition clip = one nested `if(lt(t,…))` chain, **earliest hop
  outermost**; every segment joins its neighbours exactly (the camera never
  teleports mid-window).
- Renders: one new file per request, descriptive name
  (`BASENAME_description[_N].mp4`, e.g. `tekes_full_glide_6`).
- Verification = the user watches the video (AGENTS.md rule 6). No PSNR.

## Types

| type | meaning | default params | formula (window `[T−D, T]`, `r=(t−(T−D))/D`) |
| --- | --- | --- | --- |
| **cut** | instant jump to the new x at T | — | `X1` (binary switch) |
| **glide** | constant-speed pan | D = 0.1 s | `X0 + (X1−X0)·r` |
| **ease out** | decelerate into x; arrival speed **> 0** (kills end-crawl) | D = 0.1 s, A = 0.3 | `X0 + (X1−X0)·(A·r + (1−A)·(1−(1−r)²))` |
| **ease in-out** | gimbal: accelerate, then decelerate (documented, not yet rendered) | — | `ease = r·r·(3−2·r)` |

**Crawl dial:** a pure ease-out (`1−(1−r)²`) ends at 0 px/s and visibly creeps
pixel-by-pixel into the target at 4× upscale. Blending linear ramp share `A`
keeps a minimum arrival speed `A·(ΔX/D)`: `A=0.3` = ~29 px/s arrival on a
440 px/4.5 s move. Higher `A` = smoother ending, lower = more dramatic ease.

## Phrasing lexicon (user says → build)

| user says | means |
| --- | --- |
| "cut to X at T" | cut, arrives T |
| "glide/transition to X at T" | glide, `D` = stated duration else 0.1 s |
| "get to X at T in D" / "slow transition, 1 second" | window `[T−D, T]` |
| "ease out / slow down at the end / smooth into X" | ease out |
| "not too slow at the end" | raise `A` (crawl dial) |
| "500 ms before the time" | D = 0.5 s, window ends at T |
| "start a transition at S, D long" / "at 0:57, ease out over 3 s" | **arrival T = S + D** → e.g. `60:240:easeout:3` (window `[57, 60]`) — say the arrival out loud before rendering |

## User phrasing quirks (real session notes)

- **"earlier/later / before/after" is ambiguous** — "cut it 300 ms earlier" could touch start, end, or an arrival. State the interpretation you're building ("end → 0:38.7") and offer the flip.
- **Users give odd positions (85 px); renderer requires even.** Round down to even (85 → 84) and flag it — sub-pixel at 4× upscale, but say it in the report; the user then adopts the rounded number.
- **Two-step edits on arrival times are common** ("arrive 44 is late, make it 200 ms before" → rebuild that arrival at T−X). Don't shift neighbours; the hold absorbs the delta.

## Buildable example (2 glides, D = 0.5)

Hold 110 → glide to 260 arriving 0:40 → hold → glide back to 110 arriving 0:42:

```bash
ffmpeg -y -i "$SRC" -ss 28 -t 30.97 \
  -vf "crop=268:478:'if(lt(t,39.5),110,if(lt(t,40),110+(260-110)*(t-39.5)/0.5,if(lt(t,41.5),260,if(lt(t,42),260-(260-110)*(t-41.5)/0.5,110))))':0,scale=1080:1920:flags=lanczos,format=yuv420p" \
  -c:v libx264 -crf 18 -preset medium -c:a aac -b:a 160k -movflags +faststart OUT.mp4
```

## Gotchas

- **Back-to-back transitions:** hops closer than `D` apart can't both hold — the
  second pan starts before the first arrives (0.5 s beats with `D=0.5` = whip
  reversal). Keep `D` < gap to preserve holds.
- **Fractional x is fine:** crop rounds to the nearest pixel per frame.
- **No `smoothstep` in ffmpeg 8.1.1** — build curves with plain arithmetic
  (all formulas above qualify).
- Every `X` even and in range; balance parens before rendering (count
  `(`/`)`, verify equal).

## Reference renders (in `videos/`)

- `hareini_cut_smooth_1` — glides D=0.5, many hops
- `hareini_cut_smooth_2` — glides D=0.1 (whip default feel)
- `tekes_full_glide_6` — **ease-out with A=0.3, both directions; best-so-far**
- `tekes_full_glide_4` — two-step linear "slowdown"; superseded ease-out
  attempt, don't reproduce (piecewise linear reads as jumps, not ease)