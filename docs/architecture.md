# Architecture

The app keeps artwork, behavior and creation separate. Adding a character uses the same file format as the bundled sample, rather than another code branch.

| Component | Responsibility |
| --- | --- |
| `pet-library.swift` | Manifest validation, stable IDs, atomic imports, bounded ZIP parsing and lossless export |
| `codex-pet-transfer.swift` | Local Codex metadata conversion, optional WebP decoding, verified folder export |
| `atlas.swift` | PNG validation, SHA-256, fixed-grid frame cache, alpha-aware mouse hit zones |
| `engine.swift` | Nine states, one-shot actions, still idle, settled activities and sixteen gaze directions |
| `pet-window.swift` | Transparent AppKit panel, dragging, pointer gaze, optional wandering and screen bounds |
| `settings.swift` | Persistent app preferences with quiet defaults |
| `app.swift` | Lifecycle, dynamic library, menu bar, login items, local command URLs and error handling |
| `library-view.swift` | Searchable native library, toolbar, settings and file-format explanation |
| `pet-inspector-view.swift` | Per-pet preview, visibility, hover overrides and sharing |
| `animation-preview.swift` | Independent preview clock, play/pause, speed, stepping and gaze loop |
| `hover-reaction.swift` | Safe stationary hover choices and animation descriptions |
| `design-theme.swift` | Semantic light/dark surfaces, typography accents and button feedback |
| `create-pet-view.swift` | User brief, optional reference, copied skill and documented Codex deep link |

## Storage and lifetime

Codex pet folders/ZIPs are normalized into a validated library snapshot. Only known data files are read; README contents are never executed. PNGs are preserved exactly; WebP imports are decoded into the internal PNG format. A compatible ZIP has a single optional folder prefix; traversal, duplicate basenames, links and encrypted entries are rejected before bounded streaming. Known Finder sidecars are skipped without being extracted or read; the runtime frame cache ignores unused cells while retaining the original image. Authoring validation continues to require transparent unused cells. Canonical `.petpack` exports retain their original flat schema.

Library folders live in `~/Library/Application Support/Pawlet/Library/<id>/`. Each stores `manifest.json` and the original `spritesheet.png`. Preferences, visibility and screen positions use UserDefaults under the app's bundle ID. Creation workspaces live separately beside the Library folder; deleting a runtime pet does not erase its generation sources.

Visible pets and the single selected preview load complete atlases; hiding a pet releases its window and frame cache. Thumbnails are copied from the first cell without retaining the entire atlas. Up to six pets can be active. A shared 30 Hz timer polls local pointer position and advances visible behavior; frames redraw only when their selected cell changes. The timer stops during system sleep and resumes on wake. Stored pets need no active process.

## Behavior

State commands select idle, directional running, wave, jump, failed, waiting, working or review. Waves and jumps return to the previous activity. Other activities play once and settle unless activity looping is enabled. Idle animation, wandering and pointer gaze are independent settings. User click/drag animations can be disabled without disabling other chosen motion. System Reduce Motion and the global Pause setting take priority. No automatic Codex activity monitoring is included; integrations can explicitly send state URLs.

Repeating idle/activity clips play once, then rest for the configured real-time interval. Idle rests at its neutral first pose; other activities hold their last pose. Playback speed changes the clip duration, not the rest duration. Dragging and direct greetings are immediate. Hover hit testing uses the neutral pose so an animated hand cannot create repeated artificial entries. The greeting gate requires pointer entry and idle state; loop intervals never gate greetings. Re-entry may restart any existing greeting, while a stationary pointer never repeats. The gate also respects Pause, Reduce Motion and click-through. Each greeting is explicitly timed for exactly one clip at the current speed, bypasses loop rest intervals, and restores the idle base state. Manual actions remain distinct from greetings, so hover cannot interrupt them. Global defaults live in AppSettings; per-pet overrides use `pet.<stable-id>.hoverReaction` in UserDefaults and survive renaming/relaunching. Omitting an override follows the global default.

Preview playback owns its own atlas and clock; it never shows a hidden desktop pet or changes its engine. The preview defaults to still, loops deliberately chosen clips with no rest interval, and pauses for Reduce Motion, navigation, hidden/minimized/occluded windows. It updates only when the selected frame changes. v1 excludes gaze; v2 adds a clockwise sixteen-pose loop. Frame stepping stays available under Reduce Motion. The explicit Play on desktop button is the only preview-related desktop action.

```text
pawlet://controls
pawlet://state?pet=<stable-id>&state=waiting&seconds=8
```

`pet` accepts a stable ID, a display name, or `all` (`both` is a compatibility alias). The documented raw state names are `idle`, `running-right`, `running-left`, `waving`, `jumping`, `failed`, `waiting`, `running` (working), and `review`. URLs change local state only; they cannot run commands or import remote files.

The previous `desktoppets://` scheme remains supported. Pawlet uses `com.ruzwid.pawlet`; first launch copies an existing Desktop Pets library and compatible preferences without removing the original data.

## Extension boundary

Manifest schema and sprite format have separate versions. v1/v2 geometry is intentionally fixed for compatibility with the existing artwork pipeline. Unknown metadata fields are ignored by the app; exports contain the known schema fields. Future frame timing/geometry should add a new sprite version and renderer, with fixtures and migration tests. Imported packs remain data, not plugins that execute code.

The included creation skill is an original wrapper around a separately installed generation workflow. The app does not embed an AI SDK, store an API key or invoke a paid generation job itself. Codex opens with a prepared composer, and the user submits the request. Import is a separate explicit step after inspecting the resulting pack.

## Selection and presentation

AppDelegate owns selection and synchronously refreshes the preview atlas and image when the stable selected ID changes. Views never independently load artwork from lifecycle callbacks. Library reloads also refresh the selected snapshot, and removing selection clears the old preview. Each card has separate selection and visibility buttons; showing/hiding an unselected pet leaves selection untouched.

Thumbnail presentation crops only transparent margins from the idle cell. Preview presentation computes the union of visible pixels across a complete animation (or all sixteen gaze poses), adds a small inset, and uses that same rectangle for every frame in the group. Relative jumping displacement and gaze registration remain intact. Cropped images are display caches only; imports, exports and desktop rendering use the original cells. The inspector keeps sharing and desktop actions below the scroll area so shorter windows do not hide them.
