# Pawlet

A quiet, offline Mac app for the characters you want on your desktop.

![Pet library](docs/images/library.png)

Pawlet is a native SwiftUI + AppKit app. It runs independently of Codex, has a menu bar control, and supports any compatible character through an open pet-pack format. Mochi is included as an example; adding another pet never requires editing the app.

## Install and use

Download the `.dmg` from [GitHub Releases](https://github.com/ruzwid/pawlet/releases) when a release is available. Open it, drag **Pawlet.app** to **Applications**, then open the app. Requires macOS 13 or later; the universal build supports Apple silicon and Intel. The current 0.3.0 preview is ad-hoc signed, **not Apple-notarized**, so downloaded builds may need approval in System Settings → Privacy & Security. Only approve a build you trust. Developer ID distribution is deferred while the developer account is processing. See [distribution](docs/distribution.md) for the existing release setup.

The first launch opens your pet library. Use **Import** to add a `.petpack` or a complete compatible PNG atlas; use **Share** to export a pack. Double-clicking a `.petpack` also imports it. Hover over a pet for a brief hello, click to wave, double-click to jump, drag to move it, or right-click for its other poses. The paw in the menu bar lets you reopen the library, show/hide pets, pause, or quit. Closing the library keeps the pets running.

**Still by default.** Idle animation, following the cursor, wandering and activity loops are off. Enable each separately in Settings. You can also adjust size, opacity, animation speed, click-through, window level, Spaces, Dock visibility, appearance and launch at login. macOS Reduce Motion takes priority. The library thumbnails stay still.

**Time between animations** adds 0–60 seconds of rest after each enabled idle/activity loop, with a ten-second default. Set zero for continuous playback. Hover greetings play once on entry, not repeatedly under a stationary pointer. A cooldown prevents rapid crossings from constantly waving. Turn off **Say hello on hover** for a completely still companion. Greetings respect Pause, Reduce Motion and click-through, and do not interrupt dragging or an existing action/activity.

Upgrading from the Desktop Pets preview copies your existing library and preferences into Pawlet on first launch. The previous app's files remain recoverable. `.petpack` files continue to work unchanged.

## Add any character

A `.petpack` is an ordinary flat ZIP with:

```text
manifest.json       # identity, name, description, sprite version
spritesheet.png     # every animation and gaze pose in one transparent image
preview.png         # optional thumbnail
```

There is no executable pet code. A v2 sheet is 1536 × 2288 with 192 × 208 cells: nine animation rows and sixteen gaze poses. v1 is supported without gaze. A single photograph is a creation reference, not a runnable animated pet. See the [exact format](.agents/skills/create-desktop-pet/references/format.md) and [JSON schema](docs/pet-manifest.schema.json).

The library can store many pets; up to six can be visible at once. Pets have stable IDs, so renaming does not lose their saved position. Duplicate IDs are rejected. Remove a pet using **Move to Trash**; its files remain recoverable there.

## Create with Codex

Choose **Create**, describe a character or supply a reference image, then choose **Open in Codex**. The app prepares a local creation workspace with the included [`create-desktop-pet` skill](.agents/skills/create-desktop-pet/SKILL.md), your brief and your reference. It opens a new Codex chat with the prompt filled in. Review and press **Send**; the link does not submit a job automatically. This follows the [documented Codex command interface](https://learn.chatgpt.com/docs/reference/commands).

The style picker starts at **Choose for me**. Codex picks a cohesive style that fits your character and keeps it consistent across every pose. You can still explicitly choose 3D toy, plush, pixel, clay or sticker.

New artwork requires Codex image generation and the installed **Pets plugin**. The repository includes an original standalone packaging skill; the upstream plugin and its generation tools are separate dependencies. The skill uses that pipeline through local artwork validation, then packages a `.petpack` without creating or selecting a hosted ChatGPT pet. Import the resulting pack when it is ready. There is also **Copy prompt** as a fallback. Existing pets continue to work when Codex is closed or uninstalled.

To package an already completed atlas without generating anything:

```sh
python3 -m pip install -r requirements-dev.txt
python3 .agents/skills/create-desktop-pet/scripts/package_pet.py \
  --atlas /path/to/final-atlas.png --name 'Nori' \
  --description 'A small leaf dragon.' --output /path/to/Nori.petpack
```

The helper validates structure and preserves the original PNG bytes. Visual quality and animation direction still need human review.

## Build and contribute

Install Xcode or its command-line tools, then:

```sh
bash scripts/build.sh
bash scripts/test.sh
open 'build/Pawlet.app'
```

The build has no downloaded Swift dependencies. By default it compiles a universal binary; use `ARCHS=arm64` or `ARCHS=x86_64` for a faster local build. Python/Pillow are needed only for the pack helper and its tests, never for the app at runtime. Use `bash scripts/release.sh` to create a DMG, app ZIP and SHA-256 checksums in `dist/`.

Read [CONTRIBUTING.md](CONTRIBUTING.md) and the [architecture](docs/architecture.md). GitHub Actions checks both Mac architectures; manual release builds are uploaded as workflow artifacts and do not publish a release automatically. All local user data stays in `~/Library/Application Support/Pawlet/`. No accounts, telemetry, server, API key or accessibility/screen-recording permission is needed to run pets.

## Next milestones

- Sign and notarize the public release; publish versioned GitHub downloads.
- Add library search, tags and per-pet setting overrides when the library grows.
- Add a curated gallery of downloadable packs with attribution and explicit licenses.
- Add opt-in automatic updates after a trusted release channel exists.
- Keep future sprite formats versioned; add new renderers without executing imported code.

This is an independent community app, not an official OpenAI product. Code, creation skill and the included Mochi example use the [MIT license](LICENSE). Imported artwork retains its own rights and is not relicensed by importing it.
