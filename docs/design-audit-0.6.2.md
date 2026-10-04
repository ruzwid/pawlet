# Pawlet 0.6.2 — interface and motion audit

Reviewed the 0.6.1 baseline and the 0.6.2 changes using Emil Design Engineering, Review Animations, Apple Design, Find Animation Opportunities and Write Swift. The application targets macOS 13 and uses SwiftUI/AppKit, compiled with Swift 6.3 in Swift 5 language mode. Web-specific animation rules are translated to native equivalents; this report does not claim GPU or frame-rate measurements from Instruments.

## Interface findings

| Before | After | Why |
| --- | --- | --- |
| Artwork touched the outer mini-card edges | Eight-point inset, an independently rounded stage, and an 18-point continuous outer card (`Sources/Pawlet/library-view.swift:145`) | The artwork reads as its own container, matching the reference |
| Sidebar padding looked clickable but trailing whitespace missed clicks | Full row `contentShape` and a shared button style (`Sources/Pawlet/library-view.swift:84`) | The visible row and its hit area agree |
| Show used a plus, while Hide used an eye with a slash | Eye / eye-slash pair and the same outlined accent style as choice controls (`Sources/Pawlet/library-view.swift:160`) | Related actions share their visual meaning |
| Native Menu rendering rearranged icons and dropped custom label backgrounds | Styled SwiftUI Buttons anchor native NSMenu content (`Sources/Pawlet/native-menu-button.swift:16`) | A single ellipsis, complete hit areas, consistent hover/press feedback, native menu navigation |
| Plain input borders gave little keyboard-focus feedback | Focus state has a persistent accent outline (`Sources/Pawlet/control-styles.swift:70`) | Keyboard users receive feedback independent of the pointer |
| “Quiet by default” repeated product copy in the library footer | Removed | The footer keeps the useful format/sharing action |

## Motion findings

| Before | After | Why |
| --- | --- | --- |
| Most app-owned controls had no pointer-hover feedback | A background tint fades over 100 ms with cubic-bezier `(0.23, 1, 0.32, 1)` (`Sources/Pawlet/control-styles.swift:4`) | Feedback at tens of interactions per day stays small and fast |
| Press feedback varied across plain buttons and menus | An immediate pressed tint inside the same bounds (`Sources/Pawlet/control-styles.swift:40`) | The interaction responds on press without moving text, resizing controls or delaying keyboard actions |
| Adding hover motion could introduce an accessibility regression | Reduce Motion keeps the tint and removes its fade (`Sources/Pawlet/control-styles.swift:39`) | Feedback remains legible without motion |

**Interruptibility & timing:** Hover changes retarget one opacity value; no keyframes, springs or interaction lockouts. The 100 ms budget applies only to pointer hover. Press feedback, sidebar selection, search, keyboard focus and menu choices update synchronously.

**Origin, physicality & cohesion:** Native menus originate four points below the triggering button (`Sources/Pawlet/native-menu-button.swift:65`) and retain system dismissal/navigation. The menu grows inward when screen edges constrain it. Minis keep their existing one-shot greeting and animation-clock behavior. Dragging preserves the original grab offset and follows the cursor directly (`Sources/Pawlet/pet-window.swift:122`).

**Accessibility:** Labels and selected values remain exposed for menu buttons. Menu choices use native checkmarks. Decorative chevrons are hidden from accessibility. Settings switches retain native Toggle accessibility representations, and sliders retain Increment/Decrement actions. Preview playback still stops for Reduce Motion, hidden/occluded windows and navigation (`Sources/Pawlet/animation-preview.swift:61`, `:71`, `:161`).

**Decision: Approve** the interface-motion changes. No new movement, layout tween, keyboard animation, delayed action or continuous decorative loop was introduced. Sprite atlas playback is intentionally discrete image-frame animation; the CSS transform-only rule is not a prescription to replace it or animate entire desktop windows through SwiftUI layout.

## Animation opportunities

The sweep covered press feedback, conditional content, menu/sheet origins, grid entrances, drag seams, empty states and repeated keyboard/search interactions. The single high-confidence opportunity was the requested hover feedback; it was implemented under the authorized UI work. No additional motion is recommended.

| # | Location | Today / baseline gap | Purpose | Frequency | Suggested motion |
| --- | --- | --- | --- | --- | --- |
| 1 | `Sources/Pawlet/control-styles.swift:37` | The baseline lacked consistent hover feedback; the final version closes this gap | Feedback | Tens/day; only a small change is appropriate | Background-overlay opacity `0 → 1`, 100 ms, cubic-bezier `(0.23, 1, 0.32, 1)`; retarget on exit; no transform. Native `.onHover` gates this to pointer input. Reduce Motion uses the final tint immediately. No further change needed. |

The four gates for this row pass: frequent use permits only a subtle effect; the purpose is feedback; 100 ms fits the budget; the tint leaves functional content stationary.

Rejected candidates:

- `Sources/Pawlet/library-view.swift:74` — animated sidebar navigation. **Rejected: frequency / keyboard input.** Instant changes are appropriate for a daily utility.
- `Sources/Pawlet/library-view.swift:125` — staggered card entrances during search. **Rejected: function.** Results should be available immediately as the user types.
- `Sources/Pawlet/animation-preview.swift:80` — crossfading each sprite pose. **Rejected: function.** It would blend separate frames and obscure the artwork being inspected.
- `Sources/Pawlet/pet-window.swift:128` — a spring trailing the pointer while dragging. **Rejected: function.** Placement needs direct tracking; adding lag would reduce control.
- `Sources/Pawlet/settings-view.swift:89` — bouncy switch thumbs. **Rejected: frequency / purpose.** Colour and thumb position already make the state clear.

The interface needs feedback more than choreography. The shared hover surface offers the highest return, and the final version provides it. A future motion proposal can use `improve-animations plan <suggestion>` for a separate implementation plan; none is needed for this release.

## Swift and lifetime review

- Concrete value types describe styles, menu choices and the finite menu-entry variants. The generic choice menu preserves each selection type without type erasure or casts.
- Classes are limited to AppKit identity/lifetime needs. The menu presenter weakly references the anchor owned by SwiftUI. Each NSMenuItem retains its action target through `representedObject`, because its `target` property is weak (`Sources/Pawlet/native-menu-button.swift:57`). Targets and their closures are released with the short-lived menu.
- App actions and visual feedback stay synchronous on the main UI thread. No background tasks, actors, unsafe pointers, global mutable hover state or new frame timers were added.
- Existing ObservableObject models remain compatible with macOS 13. A Swift 6 concurrency migration or macOS 14 Observation adoption is a separate project, not part of these UI fixes.

## Validation

- Universal arm64/x86_64 release build succeeded; all 39 built-in self-tests passed. The app bundle signature was verified and both DMG and ZIP were produced.
- Final native smoke checks passed in light mode at 1080 × 780 and dark mode at the 900 × 650 minimum. Checks covered preview identity/frame stepping, one-click and bulk visibility, immediate hover re-entry, Reduce Motion, settings, creation and pack round-trips.
- Manual native review verified clicking the blank right side of the Settings row, the eye-based Show all button, and the ellipsis opening a native options menu. Earlier staged checks also verified menu selection, field/card hover and unchanged preview selection after visibility actions.
- Final screenshots were inspected for inset card corners, inspector spacing, menu labels, settings colours and creation-field focus outlines. The inspector remains scrollable at minimum size.
- Smoke-test launches now reset only their isolated test preference domain, preventing manual review choices from contaminating subsequent checks. The normal library and preferences are untouched.
- Source whitespace checks passed. No Instruments frame-rate, GPU or energy measurements were performed.
