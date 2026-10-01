# Architecture

The app keeps artwork, behavior and creation separate. Adding a character uses the same file format as the bundled sample, rather than another code branch.

| Component | Responsibility |
| --- | --- |
| `PetLibrary.swift` | Manifest validation, stable IDs, atomic imports, bounded ZIP parsing and lossless export |
| `Atlas.swift` | PNG validation, SHA-256, fixed-grid frame cache, alpha-aware mouse hit zones |
| `Engine.swift` | Nine states, one-shot actions, still idle, settled activities and sixteen gaze directions |
| `PetWindow.swift` | Transparent AppKit panel, dragging, pointer gaze, optional wandering and screen bounds |
| `Settings.swift` | Persistent app preferences with quiet defaults |
| `App.swift` | Lifecycle, dynamic library, menu bar, login items, local command URLs and error handling |
| `LibraryView.swift` | Native SwiftUI library, inspector, settings and file-format explanation |
| `CreatePetView.swift` | User brief, optional reference, copied skill and documented Codex deep link |

## Storage and lifetime

Library folders live in `~/Library/Application Support/Desktop Pets/Library/<id>/`. Each stores `manifest.json` and the original `spritesheet.png`. Preferences, visibility and screen positions use UserDefaults under the app's bundle ID. Creation workspaces live separately beside the Library folder; deleting a runtime pet does not erase its generation sources.

Only visible pets load complete atlases; hiding a pet releases its window and frame cache. Thumbnails are copied from the first cell without retaining the entire atlas. Up to six pets can be active. A shared 30 Hz timer polls local pointer position and advances visible behavior; frames redraw only when their selected cell changes. The timer stops during system sleep and resumes on wake. Stored pets need no active process.

## Behavior

State commands select idle, directional running, wave, jump, failed, waiting, working or review. Waves and jumps return to the previous activity. Other activities play once and settle unless activity looping is enabled. Idle animation, wandering and pointer gaze are independent settings. User click/drag animations can be disabled without disabling other chosen motion. System Reduce Motion and the global Pause setting take priority. No automatic Codex activity monitoring is included; integrations can explicitly send state URLs.

```text
desktoppets://controls
desktoppets://state?pet=<stable-id>&state=waiting&seconds=8
```

`pet` accepts a stable ID, a display name, or `all` (`both` is a compatibility alias). The documented raw state names are `idle`, `running-right`, `running-left`, `waving`, `jumping`, `failed`, `waiting`, `running` (working), and `review`. URLs change local state only; they cannot run commands or import remote files.

## Extension boundary

Manifest schema and sprite format have separate versions. v1/v2 geometry is intentionally fixed for compatibility with the existing artwork pipeline. Unknown metadata fields are ignored by the app; exports contain the known schema fields. Future frame timing/geometry should add a new sprite version and renderer, with fixtures and migration tests. Imported packs remain data, not plugins that execute code.

The included creation skill is an original wrapper around a separately installed generation workflow. The app does not embed an AI SDK, store an API key or invoke a paid generation job itself. Codex opens with a prepared composer, and the user submits the request. Import is a separate explicit step after inspecting the resulting pack.
