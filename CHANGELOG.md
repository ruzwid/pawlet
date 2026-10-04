# Changelog

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
