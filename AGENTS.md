# Desktop Pets development

Native macOS 13+ SwiftUI/AppKit app. Build with `bash scripts/build.sh`; runtime needs no Codex, Python or network. Test meaningful engine/import/lifecycle changes with `bash scripts/test.sh`; use `--ui` for isolated native window checks.

Keep idle motion, wandering, gaze and activity loops opt-in. Respect system Reduce Motion. Imported packs are data only; reject unsafe archive entries and validate the exact bytes stored in the library. Preserve stable IDs and backward-compatible v1/v2 imports.

The repo-owned creation skill is in `.agents/skills/create-desktop-pet`. It packages local artwork and depends on the separately installed Pets plugin for new generation. Do not copy proprietary plugin implementation into this repo or upload/select a hosted pet as part of standalone creation.

Keep personal references, user-library data, secrets and build products out of commits. New example art needs explicit redistribution rights. Update docs and relevant checks when changing the public pack format or Codex handoff.
