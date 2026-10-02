# AGENTS.md — video editing with ffmpeg

This repo edits videos. You describe an edit (cut a range, change resolution,
combine, transcode…), hand over the source file(s), and the agent produces a
**new file**. The recipe for each kind of edit lives in `ai_docs/jobs/`;
shared techniques are in the docs beside them.

## First principles (never violate)

1. **Never modify a source file.** Every request renders a **new output file**
   with ffmpeg. Sources stay byte-identical.
2. **Probe before you act.** `ffprobe` the input (resolution, fps, duration,
   codecs, SAR) before writing any command — never assume anything about a
   file the user hands you.
3. **Every request maps to a job doc.** Read the relevant `ai_docs/jobs/*.md`
   and follow it end to end: probe → compute → render → verify → report.
4. **Verify before claiming success.** Check output properties with `ffprobe`
   (dimensions, fps, duration, streams). Never run pixel/PSNR checks on a
   generated video — the user verifies visually (rule 6).
5. **Report what you did.** Name the output, the exact geometry/options used,
   and the verification numbers. Never claim success without verification.
6. **No pixel-verification of generated videos.** Do not run PSNR, frame dumps,
   or any pixel-level checks on outputs. Tell the user the output path and what
   was done so **they** can look at it and verify.

## Working directory

- All media — source videos **and** rendered outputs — lives in `videos/`
  (git-ignored via `.gitignore`). Always work there; never write media into
  the repo tree outside `videos/`.
- **Never delete rendered outputs.** Every render stays in `videos/`;
  if the user wants a file removed they will remove it themselves.

## Skill

- `9x16-social` (`.agents/skills/9x16-social/`) — convert a horizontal video
  to a 9:16 vertical clip for social. Use it for any "social" / "9:16" /
  "vertical" request. Deterministic renderer bundled at
  `.agents/skills/9x16-social/scripts/render-9x16.sh`.

## Documentation index

### Jobs — one file per edit type

| File | Edit |
| --- | --- |
| `ai_docs/jobs/9x16.md` | Cut a range + horizontal slice → 9:16 (1080×1920) social clip |
| `ai_docs/jobs/cut.md` | Simple cut: trim a range, keep source geometry |
| `ai_docs/jobs/blur.md` | Blurred background: 9:16 bars above/below a centered landscape video |
| `ai_docs/jobs/text-overlay.md` | Static text overlay via pango PNG → ffmpeg overlay (Hebrew/ETL-safe) |
| `ai_docs/jobs/1x1-move.md` | Square 1:1 clip: cut range + moving crop window (eased top/middle/bottom pans, VFR frame mapping, afade trap) |

New edit type → new doc in `ai_docs/jobs/` (recipe → math → encoding →
naming → done-criteria) and a row in this table.

### Techniques — shared knowledge

| File | Subject |
| --- | --- |
| `ai_docs/transitions.md` | **Transition types + recipes** — cut / glide / ease out (types, defaults, formulas, gotchas; read first) |
| `ai_docs/timeline-hops.md` | Moving a crop position mid-clip (nested `if(lt(t,…))`, chain mechanics) |
| `ai_docs/verification.md` | Proving an edit correct without viewing pixels (PSNR) |
| `ai_docs/conventions.md` | Output naming, placement, hygiene |
| `ai_docs/vfr.md` | Variable frame rate: detect, map frame→pts, cut by frame index |