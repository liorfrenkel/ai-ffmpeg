# ai-ffmpeg

AI-driven video editing powered by ffmpeg — describe an edit, hand over a
source file, get back a **new file**. No source is ever modified.

Built as a working environment for a coding agent (pi): every kind of edit is
a documented recipe, and the agent probes each source before choosing
parameters.

## How it works

1. **Describe the edit** — cut a range, change resolution, combine, transcode,
   convert to 9:16 vertical for socials…
2. **The agent reads the recipe** for that edit in `ai_docs/jobs/`, probes the
   source with `ffprobe` (resolution, fps, duration, codecs, SAR), computes the
   exact geometry, renders with ffmpeg, and verifies the output.
3. **You verify visually** — the agent reports the output path and the exact
   options used, and never runs pixel-level checks on generated videos.

## Layout

```
ai_docs/jobs/       Recipes per edit type (9:16 conversion, simple cut,
                    blurred-background 9:16 bars, …)
ai_docs/            Shared techniques: transitions, mid-clip crop hops,
                    verification, naming conventions
.agents/skills/     Reusable agent skills (9x16-social w/ bundled renderer)
AGENTS.md           Project instructions: first principles, workflows
videos/             Media working dir (git-ignored — sources & outputs stay local)
```

## Principles

- **Never modify a source file** — every request renders a new output.
- **Probe before you act** — never assume anything about a file handed over.
- **Verify before claiming success** — outputs are checked with `ffprobe`;
  correctness is confirmed by the user's eyes, not pixel comparisons.
- **Document first** — each new edit type gets a recipe with math, encoding,
  naming, and done-criteria.

## Skills

- **9x16-social** — convert a horizontal video into a 9:16 (1080×1920) vertical
  clip with crop cuts, glides, and eased transitions. Deterministic renderer
  bundled at `.agents/skills/9x16-social/scripts/render-9x16.sh`.