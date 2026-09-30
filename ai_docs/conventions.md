# Conventions — names, locations, hygiene

## Source protection

Source files are read-only: never re-encode over them, never delete them.
Every request → a new output file. When in doubt, `shasum "$SRC"` before and
after the render — it must be identical.

Rendered outputs are never deleted either — keep every render in `videos/`;
the user removes files they don't want.

## Output naming

Short, descriptive names the user can recognize — **no long number chains**
(`hareini_cut_smooth_1`, not `hareini-cut_9x16_0028-0058_x110-260-...-100`):

```
BASENAME_description[_N].mp4
```

- `BASENAME` — source filename without extension (`hareini_cut`).
- `description` — what the edit is, in words (`smooth`, `9x16`, `glide`...).
- `_N` — optional counter when iterating on the same edit (`_1`, `_2`, ...).

## Placement

- Working media — sources **and** their outputs — live in `videos/`, which is
  git-ignored (see `.gitignore`). All rendering happens there.
- Outputs land **next to their source file** (same directory).
- Scratch frames go under a temp dir like `/tmp/*_frames/`, recreated per run.
- Nothing media-related is written into the repo tree outside `videos/`;
  the repo only holds this documentation tree (`AGENTS.md`, `ai_docs/`).

## Adding a new job

New edit type → new doc in `ai_docs/jobs/`, add a row to the AGENTS.md index.
Follow the established structure: recipe → math → encoding → naming →
done-criteria.