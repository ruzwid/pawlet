# Monitor-local per-app placement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore and stamp each mini’s place/size from the topmost fullscreen app on that mini’s monitor (else topmost window on that monitor), on Mac PR #6 and Windows PR #7.

**Architecture:** Pure “pick window from candidates” helpers (injectable for tests). Host layer enumerates on-screen windows without Accessibility. Per-pet resolve replaces global frontmost when applying/stamping. Keep existing app-keyed storage. Fold in preferred-monitor clamp already started in both worktrees.

**Tech Stack:** Swift/AppKit (`CGWindowListCopyWindowInfo`), .NET 8 WPF + Win32 enum, xUnit + Mac `scripts/test.sh`.

**Worktrees (do not create new ones):**
- Mac: `/Users/tomer.gelbhart/Projects/worktrees/pawlet/feat-per-app-placement` (`feat/per-app-placement`)
- Windows: `/Users/tomer.gelbhart/Projects/worktrees/pawlet/feat-windows-per-app-placement` (`feat/windows-per-app-placement`)

**Spec:** `docs/superpowers/specs/2026-10-06-monitor-local-placement-design.md` (already in both worktrees)

## Global Constraints

- No Accessibility permission; no screen-recording permission prompt. If an API requires either, stop and report BLOCKED.
- Storage schema unchanged (Mac UserDefaults app keys; Windows `placements.json`).
- Slot key remains app identity only (bundle ID / normalized exe path), not app×monitor.
- Prefer topmost fullscreen on the pet’s monitor; if none, topmost non-fullscreen on that monitor.
- Untrackable / no window → leave pet put (no restore).
- Pawlet’s own windows never count as placement apps.
- Mid-drag: pin stamp app at drag start; do not apply restore while any pet is dragging.
- Auto models only for SDD subagents (omit `model:` on Task dispatches).
- Commits: subject-only, no agent attribution trailers/footers. Conventional `feat(placement):` / `feat(windows):` / `test(...)` / `docs(...)`.
- Do not push unless the human asks.

---

## File map

| File | Role |
| --- | --- |
| `Sources/Pawlet/app-placement.swift` | Pure pick + preferredSafeFrame (Mac) |
| `Sources/Pawlet/monitor-app.swift` (create) | CGWindow list → candidates; resolve bundle for a pet frame |
| `Sources/Pawlet/app.swift` | Per-pet apply/stamp using monitor resolve |
| `Sources/Pawlet/pet-window.swift` | Pass pet frame into resolve; keep clamp helpers |
| `Sources/Pawlet/settings-view.swift` | Hint text for monitor-local rule |
| `Tests/app-placement-tests.swift` | Pure pick + preferredSafeFrame tests |
| `windows/.../PlacementGeometry.cs` | Pure pick + PreferredWorkArea |
| `windows/.../MonitorTopApp.cs` (create) | Win32 enum → candidates; resolve path for a pet rect |
| `windows/.../PetRuntime.cs` | Per-pet apply/stamp |
| `windows/.../PetWindow.xaml.cs` | Preferred work area clamp (already started) |
| `docs/architecture.md` (both) | Document monitor-local rule |

---

### Task 1: Commit Mac preferred-safe-frame clamp + spec

**Worktree:** Mac `feat-per-app-placement`

**Files:**
- Modify (already dirty): `Sources/Pawlet/app-placement.swift`, `Sources/Pawlet/pet-window.swift`, `Tests/app-placement-tests.swift`, `docs/architecture.md`
- Add: `docs/superpowers/specs/2026-10-06-monitor-local-placement-design.md`

**Interfaces:**
- Produces: `AppPlacement.preferredSafeFrame(for:candidates:)` already present in the dirty tree

- [ ] **Step 1: Verify tests pass**

Run: `bash scripts/test.sh`  
Expected: `"ok" : true` and packaging OK

- [ ] **Step 2: Commit**

```bash
git add Sources/Pawlet/app-placement.swift Sources/Pawlet/pet-window.swift Tests/app-placement-tests.swift docs/architecture.md docs/superpowers/specs/2026-10-06-monitor-local-placement-design.md
git commit -m "$(cat <<'EOF'
feat(placement): prefer intersecting screen for restore clamp

EOF
)"
```

Do not commit `docs/superpowers/plans/` yet if the plan file is added in Task 0 beside this; include the plan in the Mac docs commit in Task 8 if needed. Spec must be in this commit.

---

### Task 2: Pure window picker (Mac) + tests

**Worktree:** Mac `feat-per-app-placement`

**Files:**
- Modify: `Sources/Pawlet/app-placement.swift`
- Modify: `Tests/app-placement-tests.swift`

**Interfaces:**
- Produces:

```swift
struct PlacementWindowCandidate: Equatable {
    var bundleID: String
    var bounds: NSRect
    /// Front-to-back order: 0 is topmost among the provided list.
    var zOrder: Int
    var isFullscreen: Bool
}

enum AppPlacement {
    /// Prefer lowest zOrder among fullscreen candidates that intersect `monitor`;
    /// else lowest zOrder among intersecting non-fullscreen; else nil.
    static func preferredAppBundleID(
        monitor: NSRect,
        candidates: [PlacementWindowCandidate],
        selfBundleID: String?
    ) -> String?
}
```

- [ ] **Step 1: Write the failing tests** (append inside `AppPlacementTests.run`)

```swift
let monitor = NSRect(x: 0, y: 0, width: 1920, height: 1080)
let other = NSRect(x: 1920, y: 0, width: 1920, height: 1080)
let cursorFS = PlacementWindowCandidate(
    bundleID: "com.todesktop.230313mzl4w4u92", bounds: monitor, zOrder: 1, isFullscreen: true)
let chromeWin = PlacementWindowCandidate(
    bundleID: "com.google.Chrome", bounds: NSRect(x: 100, y: 100, width: 800, height: 600),
    zOrder: 0, isFullscreen: false)
try ProjectTests.require(
    AppPlacement.preferredAppBundleID(monitor: monitor, candidates: [chromeWin, cursorFS], selfBundleID: selfID)
        == "com.todesktop.230313mzl4w4u92",
    "Fullscreen on the monitor must beat a higher z-order windowed app")
let chromeOther = PlacementWindowCandidate(
    bundleID: "com.google.Chrome", bounds: NSRect(x: 2000, y: 100, width: 800, height: 600),
    zOrder: 0, isFullscreen: true)
try ProjectTests.require(
    AppPlacement.preferredAppBundleID(monitor: monitor, candidates: [chromeOther, cursorFS], selfBundleID: selfID)
        == "com.todesktop.230313mzl4w4u92",
    "Fullscreen on another monitor must not win")
let slackWin = PlacementWindowCandidate(
    bundleID: "com.tinyspeck.slackmacgap", bounds: NSRect(x: 50, y: 50, width: 900, height: 700),
    zOrder: 0, isFullscreen: false)
let cursorWin = PlacementWindowCandidate(
    bundleID: "com.todesktop.230313mzl4w4u92", bounds: NSRect(x: 200, y: 200, width: 700, height: 500),
    zOrder: 1, isFullscreen: false)
try ProjectTests.require(
    AppPlacement.preferredAppBundleID(monitor: monitor, candidates: [slackWin, cursorWin], selfBundleID: selfID)
        == "com.tinyspeck.slackmacgap",
    "With no fullscreen, topmost intersecting window wins")
try ProjectTests.require(
    AppPlacement.preferredAppBundleID(monitor: monitor, candidates: [chromeOther], selfBundleID: selfID) == nil,
    "No intersecting window must yield nil")
let pawlet = PlacementWindowCandidate(
    bundleID: selfID, bounds: monitor, zOrder: 0, isFullscreen: true)
try ProjectTests.require(
    AppPlacement.preferredAppBundleID(monitor: monitor, candidates: [pawlet, slackWin], selfBundleID: selfID)
        == "com.tinyspeck.slackmacgap",
    "Pawlet windows must never win")
```

- [ ] **Step 2: Run tests (expect fail)**

Run: `bash scripts/test.sh`  
Expected: compile error or failed require mentioning `preferredAppBundleID` / `PlacementWindowCandidate`

- [ ] **Step 3: Implement minimal picker**

Add to `app-placement.swift`:

```swift
struct PlacementWindowCandidate: Equatable {
    var bundleID: String
    var bounds: NSRect
    var zOrder: Int
    var isFullscreen: Bool
}

extension AppPlacement {
    static func preferredAppBundleID(
        monitor: NSRect,
        candidates: [PlacementWindowCandidate],
        selfBundleID: String?
    ) -> String? {
        let intersecting = candidates.filter { candidate in
            guard intersectionArea(monitor, candidate.bounds) > 0 else { return false }
            return isTrackable(bundleID: candidate.bundleID, selfBundleID: selfBundleID)
        }
        if let bestFS = intersecting.filter(\.isFullscreen).min(by: { $0.zOrder < $1.zOrder }) {
            return bestFS.bundleID
        }
        return intersecting.min(by: { $0.zOrder < $1.zOrder })?.bundleID
    }
}
```

(`intersectionArea` already private on `AppPlacement` from preferredSafeFrame work; if file-private access blocks, make it `fileprivate`/`static` usable from both.)

- [ ] **Step 4: Run tests (expect pass)**

Run: `bash scripts/test.sh`  
Expected: `"ok" : true`

- [ ] **Step 5: Commit**

```bash
git add Sources/Pawlet/app-placement.swift Tests/app-placement-tests.swift
git commit -m "$(cat <<'EOF'
feat(placement): pick monitor-local app from window candidates

EOF
)"
```

---

### Task 3: Mac CGWindow enumerator + per-pet resolve wiring

**Worktree:** Mac `feat-per-app-placement`

**Files:**
- Create: `Sources/Pawlet/monitor-app.swift`
- Modify: `Sources/Pawlet/app.swift` (replace global `placementAppBundleID()` usage for apply/stamp with per-frame resolve)
- Modify: `Sources/Pawlet/pet-window.swift` (stamp uses resolve for `panel.frame`; drag pin stores bundle from resolve at drag start)
- Modify: `Sources/Pawlet/settings-view.swift` (hint)
- Modify: `docs/architecture.md` (one sentence on monitor-local topmost/fullscreen)
- Ensure `monitor-app.swift` is compiled: if the project uses a static file list, add it wherever other Sources are listed (check `project.yml` / `Package.swift` / `scripts/build.sh`)

**Interfaces:**
- Consumes: `AppPlacement.preferredAppBundleID`, `AppPlacement.isTrackable`, `AppPlacement.preferredSafeFrame`
- Produces:

```swift
enum MonitorFrontApp {
    /// Fullscreen if window bounds cover `screen.frame` within `slop` points on each edge.
    static let fullscreenSlop: CGFloat = 2

    static func candidates(excludingBundleIDs: Set<String>) -> [PlacementWindowCandidate]
    static func preferredBundleID(forPetFrame frame: NSRect, selfBundleID: String?) -> String?
}
```

- [ ] **Step 1: Find how Sources are compiled**

Run: `rg -n "app-placement.swift|Sources/Pawlet" scripts project.yml Package.swift Makefile 2>/dev/null | head -40`  
Add `monitor-app.swift` the same way sibling files are included.

- [ ] **Step 2: Implement `monitor-app.swift`**

```swift
import AppKit
import ApplicationServices

enum MonitorFrontApp {
    static let fullscreenSlop: CGFloat = 2

    static func preferredBundleID(forPetFrame frame: NSRect, selfBundleID: String?) -> String? {
        let screens = NSScreen.screens.map(\.frame)
        guard let monitor = AppPlacement.preferredSafeFrame(for: frame, candidates: screens) else { return nil }
        let skip = Set([selfBundleID].compactMap { $0 })
        return AppPlacement.preferredAppBundleID(
            monitor: monitor, candidates: candidates(excludingBundleIDs: skip), selfBundleID: selfBundleID)
    }

    static func candidates(excludingBundleIDs: Set<String>) -> [PlacementWindowCandidate] {
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        var result: [PlacementWindowCandidate] = []
        var z = 0
        for entry in info {
            guard let bundleID = bundleID(from: entry), !excludingBundleIDs.contains(bundleID) else { continue }
            guard let bounds = cgBounds(from: entry) else { continue }
            let layer = entry[kCGWindowLayer as String] as? Int ?? 0
            if layer != 0 { continue } // normal app windows only
            let fs = isFullscreen(bounds: bounds)
            result.append(PlacementWindowCandidate(bundleID: bundleID, bounds: bounds, zOrder: z, isFullscreen: fs))
            z += 1
        }
        return result
    }

    private static func bundleID(from entry: [String: Any]) -> String? {
        guard let pid = entry[kCGWindowOwnerPID as String] as? pid_t,
              let app = NSRunningApplication(processIdentifier: pid) else { return nil }
        return app.bundleIdentifier
    }

    private static func cgBounds(from entry: [String: Any]) -> NSRect? {
        guard let dict = entry[kCGWindowBounds as String] as? [String: Any] else { return nil }
        var rect = CGRect.zero
        guard CGRectMakeWithDictionaryRepresentation(dict as CFDictionary, &rect) else { return nil }
        // CGWindow bounds use origin at bottom-left of the primary display (same as Cocoa global).
        return NSRect(x: rect.origin.x, y: rect.origin.y, width: rect.size.width, height: rect.size.height)
    }

    private static func isFullscreen(bounds: NSRect) -> Bool {
        for screen in NSScreen.screens {
            let f = screen.frame
            if abs(bounds.minX - f.minX) <= fullscreenSlop,
               abs(bounds.maxX - f.maxX) <= fullscreenSlop,
               abs(bounds.minY - f.minY) <= fullscreenSlop,
               abs(bounds.maxY - f.maxY) <= fullscreenSlop {
                return true
            }
        }
        return false
    }
}
```

If `CGRectMakeWithDictionaryRepresentation` / coordinate comments prove wrong on a dual-monitor smoke check, fix conversion in a follow-up commit in this task (do not invent Accessibility).

- [ ] **Step 3: Wire `app.swift`**

Replace global apply with per-pet:

```swift
func placementAppBundleID(forPetFrame frame: NSRect) -> String? {
    MonitorFrontApp.preferredBundleID(forPetFrame: frame, selfBundleID: Bundle.main.bundleIdentifier)
}

/// Legacy name used by Size menu when no pet frame is handy: resolve using main screen center.
func placementAppBundleID() -> String? {
    let screen = NSScreen.main ?? NSScreen.screens.first
    let frame = screen.map { NSRect(x: $0.frame.midX, y: $0.frame.midY, width: 1, height: 1) } ?? .zero
    return placementAppBundleID(forPetFrame: frame)
}

func applyRememberedAppPlacement(animated: Bool = true) {
    guard settings.rememberPlacePerApp else { return }
    if pets.contains(where: { $0.isDragging }) { return }
    for pet in pets where pet.visible {
        guard let bundleID = placementAppBundleID(forPetFrame: pet.panelFrame) else { continue }
        pet.applyRememberedPlacement(bundleID: bundleID, animated: animated)
    }
}
```

Expose `panelFrame` (or `frame`) on the pet window wrapper as `NSRect` of the panel.

In `savePosition` / drag pin paths, call `owner.placementAppBundleID(forPetFrame: panel.frame)` instead of global frontmost.

Keep observing `NSWorkspace.didActivateApplicationNotification`. Also observe `NSApplication.didChangeScreenParametersNotification` already present (`screensChanged`) and call `applyRememberedAppPlacement(animated: false)` after clamp.

- [ ] **Step 4: Update settings hint**

Replace the Remember place per app hint with text that states restore follows the topmost fullscreen app on the mini’s monitor (else topmost window on that monitor).

- [ ] **Step 5: Build and test**

Run: `bash scripts/test.sh`  
Expected: `"ok" : true`

- [ ] **Step 6: Commit**

```bash
git add Sources/Pawlet/monitor-app.swift Sources/Pawlet/app.swift Sources/Pawlet/pet-window.swift Sources/Pawlet/settings-view.swift docs/architecture.md
# plus any project file that lists sources
git commit -m "$(cat <<'EOF'
feat(placement): resolve place from topmost app on pet monitor

EOF
)"
```

---

### Task 4: Commit Windows preferred-work-area clamp + spec

**Worktree:** Windows `feat-windows-per-app-placement`

**Files:** dirty clamp + `docs/superpowers/specs/2026-10-06-monitor-local-placement-design.md`

- [ ] **Step 1: Verify**

Run: `export PATH="$HOME/.dotnet:$PATH" && dotnet test windows/tests/Pawlet.Tests/Pawlet.Tests.csproj`  
Expected: all passed

- [ ] **Step 2: Commit**

```bash
git add windows/src/Pawlet.Core/Storage/PlacementGeometry.cs windows/src/Pawlet/Pets/PetWindow.xaml.cs windows/tests/Pawlet.Tests/PlacementStampKeyTests.cs docs/architecture.md docs/superpowers/specs/2026-10-06-monitor-local-placement-design.md
git commit -m "$(cat <<'EOF'
feat(windows): clamp placement to preferred monitor work area

EOF
)"
```

---

### Task 5: Pure window picker (Windows) + tests

**Worktree:** Windows `feat-windows-per-app-placement`

**Files:**
- Modify: `windows/src/Pawlet.Core/Storage/PlacementGeometry.cs`
- Modify: `windows/tests/Pawlet.Tests/PlacementStampKeyTests.cs` (or new `MonitorFrontAppTests.cs` in same project)

**Interfaces:**
- Produces:

```csharp
public readonly record struct PlacementWindowCandidate(
    string AppKey,
    double Left, double Top, double Right, double Bottom,
    int ZOrder,
    bool IsFullscreen);

public static string? PreferredAppKey(
    double monitorLeft, double monitorTop, double monitorRight, double monitorBottom,
    IReadOnlyList<PlacementWindowCandidate> candidates,
    string? selfAppKey);
```

- [ ] **Step 1: Failing tests** (mirror Mac cases: fullscreen wins, other-monitor ignored, no-fullscreen topmost, empty → null, self skipped)

- [ ] **Step 2: Run** `dotnet test --filter PreferredAppKey` → fail

- [ ] **Step 3: Implement** `PreferredAppKey` + intersection helper in `PlacementGeometry` (same logic as Swift)

- [ ] **Step 4: Run** → pass

- [ ] **Step 5: Commit** `feat(windows): pick monitor-local app from window candidates`

---

### Task 6: Windows enumerator + PetRuntime per-pet wiring

**Worktree:** Windows `feat-windows-per-app-placement`

**Files:**
- Create: `windows/src/Pawlet/Pets/MonitorTopApp.cs`
- Modify: `windows/src/Pawlet/Pets/PetRuntime.cs`
- Modify: `windows/src/Pawlet/Library/LibraryWindow.xaml` or settings copy if the Remember toggle has a description
- Modify: `docs/architecture.md`

**Interfaces:**
- Consumes: `PlacementGeometry.PreferredAppKey`, `PlacementStore.IsTrackable`, `PetWindow.AllWorkAreas` / preferred monitor
- Produces: `MonitorTopApp.PreferredAppKey(double left, double top, double width, double height, string? selfExe)`

- [ ] **Step 1: Implement `MonitorTopApp`** using Win32 `EnumWindows` + `GetWindowRect` + `IsWindowVisible`. Skip tool windows (`WS_EX_TOOLWINDOW`), owned popups if needed, and the current process. Z-order = enum order (topmost first). Fullscreen = rect covers a monitor’s `Bounds` (Forms `Screen`) within 2 DIP/px slop using the same DIP scaling approach as `PetWindow.AllWorkAreas`. Map HWND → normalized exe via existing ForegroundWatcher path helper (extract shared `TryGetMainModulePath(pid)` if duplicated).

- [ ] **Step 2: Change `ApplyAppPlacementToOpenWindows`**

```csharp
foreach (var entry in _open.Values)
{
    if (entry.Window.IsDragging) continue;
    var key = MonitorTopApp.PreferredAppKey(
        entry.Window.Left, entry.Window.Top, entry.Window.Width, entry.Window.Height, _selfExePath);
    if (!PlacementStore.IsTrackable(key, _selfExePath)) continue;
    var appOrigin = _placements.RememberedAppOrigin(entry.PetId, key);
    Point? origin = appOrigin is { } o ? new Point(o.X, o.Y) : null;
    entry.Window.ApplyRememberedPlacement(origin, ResolvedScale(entry.PetId, key), _settings.Opacity);
}
```

Update `ResolvedScale` / stamp paths to take an explicit app key (or resolve from window rect) instead of only `_foregroundAppKey`. Keep `_foregroundAppKey` / watcher as a **trigger** to re-run apply (and update last-trackable for drag pin if still useful); do not use global key as the apply source.

Drag stamp: resolve key from window position at drag start (existing pin pattern), not global foreground.

- [ ] **Step 3: `dotnet test` + `dotnet build windows/src/Pawlet/Pawlet.csproj`**

- [ ] **Step 4: Commit** `feat(windows): resolve place from topmost app on pet monitor`

---

### Task 7: Docs + settings copy parity + plan file

**Worktrees:** both

- [ ] Ensure architecture + settings strings match the spec wording on Mac and Windows.
- [ ] Add this plan under `docs/superpowers/plans/2026-10-06-monitor-local-placement.md` on **both** worktrees (copy).
- [ ] Commit each: `docs(placement): document monitor-local frontmost placement`

---

### Task 8: Manual dual-monitor smoke (human or agent notes)

Cannot fully automate. Implementer leaves a short checklist in the PR body / report:

- [ ] Cursor topmost monitor 1; Chrome focus monitor 2 → mini on 1 stays
- [ ] Fullscreen on monitor 1 beats windowed underneath
- [ ] No fullscreen → topmost windowed wins
- [ ] Drag across monitors stamps destination monitor’s top app (pin at drag start)

No commit required unless checklist text is added to PR description by the human later.

---

## Self-review (plan vs spec)

| Spec requirement | Task |
| --- | --- |
| Monitor from pet frame (max intersection) | 1/4 clamp + 3/6 resolve |
| Prefer topmost fullscreen else topmost | 2, 5, 3, 6 |
| Untrackable → stay put | 3, 6 |
| Exclude self | 2, 5, 3, 6 |
| Storage unchanged | Global Constraints |
| No Accessibility | Global Constraints + Task 3/6 |
| Stamp/Size/drag pin | 3, 6 |
| Secondary monitor clamp | 1, 4 |
| Acceptance cases | 2/5 unit + Task 8 |

No TBD placeholders in task steps. Types aligned: `PlacementWindowCandidate` / `preferredAppBundleID` (Mac) and `PlacementWindowCandidate` / `PreferredAppKey` (Windows).
