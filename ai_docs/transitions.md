# Transitions — type reference (vocabulary → recipe)

Canonical lookup for "which crop transition does the user want". Deep dives:
`ai_docs/timeline-hops.md` (hop chains), `ai_docs/glides.md` (curves, easing,
worked renders).

## Ground rules

- Times are **original-timeline seconds** — `-i` first, `-ss` after, so `t` in
  the crop expression is the original timeline. Never break this.
- `x` = px **from the left of the source frame**; even, in `[0, W−CW]`
  (848×478 → `[0, 580]`, slice 268 wide).
- Between transitions the crop **holds** its position.
- Multi-transition clip = one nested `if(lt(t,…))` chain, earliest hop
  outermost. Every render gets its own new file; never reuse `if` values
  without confirming the whole timeline.
- Verification = the user watches the video (AGENTS.md rule 6). Never run
  PSNR/pixel checks on outputs.

## Types

| type | meaning | default params | position formula over window `[T−D, T]` |
| --- | --- | --- | --- |
| **cut** | instant jump to the new x at T | — | `X1` (binary switch) |
| **glide** | constant-speed pan | D = 0.1 s (100 ms) | `X0 + (X1−X0)·(t−(T−D))/D` |
| **ease out** | decelerate into x; **arrival speed stays > 0** (kills the end-crawl) | D = 0.1 s, A = 0.3 | `X0 + (X1−X0)·ease`, `ease = A·r + (1−A)·(1−(1−r)²)`, `r = (t−(T−D))/D` |
| **ease in-out** | gimbal: accelerate, then decelerate (documented, not yet rendered) | — | `ease = r·r·(3−2·r)` |

Ramps: `r` goes 0→1 across the window; every segment joins its neighbours
exactly (continuity — the camera never teleports mid-window).

## Phrasing lexicon (user says → build)

| user says | means |
| --- | --- |
| "cut to X at T" | cut, arrives T |
| "glide/transition to X at T" | glide unless a curve word is used; `D` = stated duration else default |
| "get to X at T in D" / "slow transition, 1 second" | window `[T−D, T]` |
| "ease out / slow down at the end / smooth into X" | ease out (not plain glide) |
| "not too slow at the end" | raise `A` (more linear floor) — crawl dial |
| "500 ms before the time" | D = 0.5 s, window ends at T |

## Reference renders (in `videos/`)

- `hareini_cut_smooth_1` — glides D=0.5, many hops
- `hareini_cut_smooth_2` — glides D=0.1 (the "whip" default feel)
- `tekes_full_glide_6` — **ease-out with A=0.3, both directions; best-so-far**
- `tekes_full_glide_4` — two-step linear "slowdown" — an ease-out attempt now
  superseded; don't reproduce (piecewise linear reads as jumps, not ease)