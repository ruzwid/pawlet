# Changelog

## 0.6.1

- Use continuous squircle-style corners for cards, panels, buttons, search, animation chips and switches.
- Give creation fields and dropdowns matching themed borders while retaining native editing and menu accessibility.

## 0.6.0

- Give light mode a paper-and-olive palette inspired by the supplied Granola reference.
- Replace the system settings form with themed sections and switches with distinct on/off colours and native accessibility semantics.
- Add Show all minis / Hide all minis to the sidebar, preserving the selected preview and individual settings.
- Remove the six-window cap so Show all covers the complete library.
- Use Minis throughout application copy, menus and errors while retaining compatible pack extensions, paths and metadata keys.

## 0.5.2

- Redraw the paw with plump toe beans and a soft rounded pad; use it across the app, sidebar and menu bar.
- Rename the library to Minis, simplify its heading, and remove repeated taglines and the sidebar section label.
- Reduce sidebar padding and compact the desktop count and pause controls.

## 0.5.1

- Fix stale preview artwork by loading the selected pet through one app-owned selection path.
- Add one-click Show pet / Hide pet actions to every card without changing the current selection.
- Tighten spacing, align the hover setting, and keep desktop playback and sharing actions visible in the inspector.
- Trim transparent margins for thumbnail and preview presentation, using one shared crop per animation to preserve relative pose movement. Stored artwork is unchanged.

## 0.5.0

- Refresh the native library, settings and creation sheet with a warm light/dark palette and a searchable companion collection.
- Move Pets folder to the library toolbar and open the entire library; keep individual files in each pet’s options menu.
- Add isolated animation previews with continuous looping, pause, speed, frame stepping and sixteen gaze poses where available.
- Add global and per-pet hover choices, including Jump / Hop toward you, with immediate re-entry and a one-clip return to idle.
- Keep gallery thumbnails still and pause preview playback for hidden windows, navigation and Reduce Motion.

## 0.4.1

- Import Finder-created Codex ZIPs while ignoring __MACOSX and .DS_Store metadata.
- Read only playable atlas cells, allowing existing pets with extra unused poses.
- Preserve source pixels and keep required-frame, image, hash and archive-safety checks.

## 0.4.0

- Remove hover cooldowns: each pointer re-entry can wave independently of loop intervals.
- Allow 25–175% pet size, including persisted settings and native panel resizing.
- Add Open folder beside each pet and reveal exported packs in Finder.
- Import Codex pet folders, pet.json and flat/wrapped share ZIPs with names and IDs intact.
- Export Codex folders and ordinary ZIPs alongside existing .petpack support.
- Preserve PNG bytes and decode compatible WebP sprite sheets to PNG on import.
- Document clone/build setup and two-way local desktop pet transfers without Apple Developer credentials.

## 0.3.0 — Pawlet

- Rename the native app, bundle identifier, local storage and executable to Pawlet.
- Preserve previous Desktop Pets libraries/preferences on first launch and retain legacy command URLs.
- Default creation style to Choose for me with a consistent-style instruction.
- Add configurable 0–60 second rest intervals for enabled idle/activity loops, defaulting to ten seconds.
- Add one-shot hover greetings with cooldown, pause/reduced-motion gating and an independent setting.
- Round the paw icon and share the same mark across the Dock, menu bar and app interface.
- Keep direct-download signing/notarization deferred while Apple Developer enrollment processes.

## 0.2.0

- Native pet library, inspector, menu bar controls, Dock app and settings.
- Quiet defaults, independent motion toggles and system Reduce Motion support.
- Extensible pet packs with stable IDs, import/export, PNG import, rename and recoverable removal.
- Compatible v1/v2 atlases with original artwork preserved.
- Local Codex creation handoff and a repository-owned packaging skill.
- Universal Mac build, DMG/ZIP packaging, contributor docs and CI checks.

Preview distribution is ad-hoc signed; Developer ID signing and Apple notarization are pending.
