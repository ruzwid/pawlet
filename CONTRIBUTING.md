# Contributing

Small, focused changes are welcome. For a feature that changes the file format or desktop behavior, open an issue describing the user problem before implementing a large redesign.

## Development

Build with `bash scripts/build.sh`. Run `bash scripts/test.sh` after changing the engine, import/export, app lifecycle or creation handoff. Python packaging tests need `python3 -m pip install -r requirements-dev.txt`. Run `bash scripts/test.sh --ui` to exercise native windows and save screenshots under `build/ui-test/`; that mode uses isolated preferences and a test library, not your normal pets.

Check light/dark appearance, keyboard navigation, a small window, Reduce Motion and the menu bar for UI changes. Avoid animation in settings and thumbnails. Desktop motion must remain opt-in, apart from brief direct interactions.

## Adding example pets

New characters work through pet packs; no Swift changes are needed. Share a `.petpack` with an explicit artwork license and attribution. Keep personal reference photographs, private briefs and large generation-source folders out of the repository. Runtime packs contain only image and metadata files. Show the nine animation states and gaze directions when proposing an example pet; a valid grid alone does not establish visual quality.

## Pull requests

Explain the concrete behavior before and after your change and how you verified it. Preserve v1/v2 imports and stable IDs. New metadata should be optional; breaking geometry changes require a new sprite version and a migration plan. Never make an imported pack execute code or fetch a URL.

## Reporting bugs

Include macOS version, app version, architecture and steps to reproduce. For a pack-related issue, attach a minimal pack you are allowed to share and the exact error. Do not include your whole Application Support directory or personal creation references.
