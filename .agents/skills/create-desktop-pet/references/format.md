# Standalone pet format

`.petpack` is a flat ZIP containing `manifest.json` and `spritesheet.png`; `preview.png` is optional. No scripts, executables, URLs, nested directories or extra files belong in a runtime pet pack. Creation sources and QA can stay beside it in the workspace.

```json
{
  "schemaVersion": 1,
  "id": "a-stable-local-id",
  "name": "Nori",
  "description": "A little leaf dragon.",
  "spriteVersion": 2,
  "atlas": "spritesheet.png"
}
```

Optional fields: `author` (up to 100 characters), `artworkSHA256` (64 hex characters). Names are 1–60 characters without control characters; descriptions up to 600; IDs 1–64 ASCII letters, digits, hyphens or underscores. Unknown metadata is ignored. IDs identify the pet even after renaming.

The PNG must be under 20 MiB with transparent unused cells. Packs must be under 25 MiB. Cell geometry is fixed at 192 × 208, eight columns.

| Row | State | Frames |
| --- | --- | ---: |
| 0 | idle | 6 |
| 1 | running-right | 8 |
| 2 | running-left | 8 |
| 3 | waving | 4 |
| 4 | jumping | 5 |
| 5 | failed | 8 |
| 6 | waiting | 6 |
| 7 | running (active work, not foot-running) | 6 |
| 8 | review | 6 |
| 9 | gaze 000–157.5° clockwise | 8 |
| 10 | gaze 180–337.5° clockwise | 8 |

v2 is 1536 × 2288, 73 poses, 15 unused transparent cells. Gaze begins at **up**, then advances clockwise every 22.5° in screen coordinates. The cardinals are up, screen-right, down, screen-left. Keep the body anchored while gaze changes.

v1 is 1536 × 1872, rows 0–8 only, 57 poses and the same 15 unused transparent cells. Set `spriteVersion` to 1. It has no gaze tracking.

## Codex desktop transfer

Pawlet also imports a Codex pet folder or ZIP with `pet.json` and `spritesheet.png`/`spritesheet.webp`. Codex fields are `id` (optional), `displayName` (optional), `description`, `spriteVersionNumber` (1 or 2), and `spritesheetPath` (one of those two image filenames). Absent sprite version defaults to 1. Folder imports use the folder name as the missing identity fallback. Metadata and PNG artwork are preserved; WebP artwork is decoded to the internal PNG format.

Share → Export for Codex saves `pet.json`, `spritesheet.png` and the Pawlet manifest together. Save under `~/.codex/pets/` for local desktop selection. This is separate from ChatGPT Work web upload. It requires no artwork regeneration or hosted pet creation. A compatible ZIP may wrap one pet in one folder and include README.md; canonical .petpack files stay flat with the original schema above.
