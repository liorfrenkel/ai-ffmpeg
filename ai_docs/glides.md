# Glides — smooth pan transitions between crop positions

A **glide** turns a hard crop hop (jump) into a short camera-like pan: hold the
current position, then glide to the next position over a window that ends
exactly on the hop's time. The camera doesn't jump — it moves.

## Recipe

For a hop at time `T` from `X0` to `X1`, with glide duration `D`:

| t | x |
| --- | --- |
| `t < T−D` | `X0` (hold) |
| `T−D ≤ t < T` | `X0 + (X1−X0)·(t−(T−D))/D` (glide, arrives exactly at `T`) |
| `t ≥ T` | `X1` (hold next) |

In the crop filter (single hop):

```
crop=W:H:'if(lt(t,T-D),X0,X0+(X1-X0)*(t-(T-D))/D)':0
```

Multiple glides in one clip = nested `if(lt(t,…))` chain, one level per hop —
same structure and rules as `ai_docs/timeline-hops.md`: keep `-i` before `-ss`
so `t` stays on the original timeline.

## Parameters

- `T` — hop time, seconds of the original timeline (fractional OK: 0:32.5 → `32.5`).
- `D` — glide duration in seconds (`0.5` = 500 ms, `0.1` = 100 ms).
- `X0`, `X1` — even, in-range crop offsets.

Pan speed = `(X1−X0)/D`: a 150 px move at `D=0.5` is 300 px/s; at `D=0.1` it's
1500 px/s (≈ 50 px/frame @ 30 fps — reads as a flick, not a pan). Long,
short, or in-between — pick `D` for the feel.

## Rules / gotchas

- **Back-to-back glides:** when two hop times are closer than `D` apart, the
  second glide starts before the first arrives and the intermediate position
  is never held (e.g. 0.5 s beat spacing with `D=0.5` → whip reversal).
  Use `D` smaller than the gap to keep a hold.
- **Continuity:** every glide starts exactly at the current position and ends
  exactly at the next — within a glide the camera never teleports.
- **Fractional x is fine:** crop rounds x to the nearest pixel per frame.
- **Easing:** the plain form is constant-speed. No `smoothstep` in ffmpeg
  8.1.1 — build curves with plain arithmetic:
  - ease-in-out ("gimbal"): ramp `r` → `r*r*(3-2*r)`
  - ease-out (decelerate into target): ramp `r` → `1-(1-r)*(1-r)`
  - **ease-out with speed floor** (recommended — avoids end-of-glide crawl):

    ```
    ease = A*r + (1-A)*(1-(1-r)*(1-r))      # A ≈ 0.15–0.40 share of linear
    ```

    A pure ease-out ends at **0 px/s**, so the camera creeps pixel-by-pixel
    into the target (visible at 4× upscale). Blending a share `A` of the
    linear ramp keeps a minimum arrival speed of `A·(ΔX/D)`. `A` is the
    "crawl dial": higher = smolder end, lower = more dramatic ease.
- Verify visually — no pixel checks (AGENTS.md rule 6).

## Example (2 hops, D = 0.5)

Hold 110 → glide to 260 arriving at 0:40 → hold 260 → glide back to 110
arriving at 0:42:

```bash
ffmpeg -y -i "$SRC" -ss 28 -t 30.97 \
  -vf "crop=268:478:'if(lt(t,39.5),110,if(lt(t,40),110+(260-110)*(t-39.5)/0.5,if(lt(t,41.5),260,if(lt(t,42),260-(260-110)*(t-41.5)/0.5,110))))':0,scale=1080:1920:flags=lanczos,format=yuv420p" \
  -c:v libx264 -crf 18 -preset medium -c:a aac -b:a 160k -movflags +faststart OUT.mp4
```

## Worked cases

`hareini_cut_smooth_1` / `hareini_cut_smooth_2` — waypoints: 0:28→x110,
0:32.5→260, 0:33→110, 0:35.5→260, 0:36→110, 0:37.4→260, 0:40→110, 0:46.5→260,
0:48→100 (held to end); every hop glided at `D=0.5` resp. `D=0.1`.

`tekes_full_glide_6` — 2:06→x0 hold, glide 0→440 (2:14–2:18.5) and back
440→130 (2:22–2:24), **both eased-out with a 30% linear floor** (`A=0.3`);
440 held 2:18.5–2:22, 130 held to 2:29.