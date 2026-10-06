# Monitor-local per-app placement

**Status:** approved in chat 2026-10-06  
**Applies to:** Mac PR #6 (`feat/per-app-placement`), Windows PR #7 (`feat/windows-per-app-placement`)

## Problem

Open placement PRs key restore/stamp on the **global** frontmost app. Focusing Chrome on monitor 2 moves minis that live on monitor 1, even when Cursor is still the top app on monitor 1.

## Goal

Each mini follows the app that is topmost **on the monitor that mini sits on**. Prefer a fullscreen window on that monitor; if none, use the topmost non-fullscreen window.

### Example

- Mini parked on monitor 1 while Cursor is topmost there → stamp/restore Cursor’s slot.
- User focuses Chrome fullscreen (or windowed) on monitor 2 → mini on monitor 1 **does not** move.
- User brings Slack to the top on monitor 1 → mini restores Slack’s slot (if any).

## Non-goals

- Storage keyed by monitor ID (slots stay per app only).
- Following an app window’s frame (absolute origin/size only).
- Accessibility or screen-recording permission.
- Perfect mixed-DPI secondary metrics beyond “correct monitor.”

## Behavior

### Which app owns a pet

1. **Monitor:** screen whose visible/work area has the largest intersection with the pet frame (same idea as preferred safe-frame clamp).
2. **Candidate windows:** on-screen windows that intersect that monitor, excluding Pawlet’s own windows.
3. **Pick:** topmost **fullscreen** candidate if any; else topmost candidate.
4. **Key:** map window → trackable app id (Mac bundle ID / Windows normalized main-module path). Untrackable or none → leave the pet put (no restore).

### Fullscreen

Treat a window as fullscreen when its frame covers that monitor’s display bounds within a small slop (not merely maximized-to-work-area).

### When to re-evaluate

- Existing focus / foreground hooks.
- Enough window or z-order signal that monitor-local topmost can change without a global focus change (fullscreen enter/exit on another display, etc.).
- After user drag ends: re-resolve for that pet’s new monitor.
- Display configuration changes: clamp, then re-resolve.

### Stamp and Size

Unchanged product locks, with the app key taken from **monitor-local** resolve:

- Drag and “Bring minis back” stamp origin for the resolved trackable app (pin app at drag start).
- Right-click Size writes the active slot for the resolved app; Library/self still writes pet-level size.
- Wander / sleep / hide / quit update global origin only.
- Missing app origin → stay put; missing app size → pet-level / settings fallback.

### Multi-monitor clamp

Restore/clamp use the preferred monitor work area (max intersection), not primary-only. Fold the existing clamp helpers into this work; do not ship clamp-only as the whole fix.

## Approach

**Per-pet resolve** on each relevant event: monitor from pet frame → topmost fullscreen else topmost window → apply that app’s slot. Prefer this over a per-monitor cache (fewer invalidation edge cases; cost is fine for a handful of minis).

## Platform notes

| | Mac | Windows |
| --- | --- | --- |
| Trigger today | `NSWorkspace.didActivateApplicationNotification` | `EVENT_SYSTEM_FOREGROUND` |
| Needed extra | Window list / bounds for z-order on the pet’s screen (`CGWindowList` family, no Accessibility) | Enumerate top-level windows + monitor hit-test (Win32); keep foreground hook as one trigger |
| App key | Bundle ID | Normalized exe path |
| Permissions | Stay within “no Accessibility / no screen recording” product bar | Same spirit; no UI Automation for titles |

If a public API cannot supply bounds without a new permission, stop and flag before shipping a permission prompt.

## Storage

No schema change. Existing `pet.<id>.app.<key>.{x,y,size}` (Mac) and `placements.json` app map (Windows) remain.

## Test plan (acceptance)

- [ ] Cursor topmost on monitor 1, stamp place; Chrome focused on monitor 2 → monitor 1 mini stays on Cursor slot.
- [ ] Fullscreen app on monitor 1 beats a non-fullscreen window underneath for slot choice.
- [ ] No fullscreen on monitor → topmost windowed app on that monitor wins.
- [ ] Drag mini to the other monitor; drop stamps the app topmost on the **destination** monitor (pin at drag start still applies mid-drag).
- [ ] Untrackable / empty → stay put.
- [ ] Secondary-monitor saved origin restores onto that monitor (not yanked to primary).
- [ ] Existing suites: `bash scripts/test.sh` (Mac); `dotnet test` Windows placement tests.

## Open follow-ups (not blocking)

- How often to poll or which Win32/Mac notifications catch fullscreen-on-other-display without focus change (implement the smallest reliable set).
- Exact fullscreen slop in points/pixels (tune against one real dual-monitor setup).
