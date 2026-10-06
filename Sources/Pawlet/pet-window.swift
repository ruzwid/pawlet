import AppKit

final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class PetView: NSView {
    weak var pet: DesktopPet?
    var sprite: NSImage? { didSet { needsDisplay = true } }
    override var isOpaque: Bool { false }
    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.current?.imageInterpolation = .high
        sprite?.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1)
    }
    override func mouseDown(with event: NSEvent) { pet?.beginDrag(event) }
    override func mouseDragged(with event: NSEvent) { pet?.drag(event) }
    override func mouseUp(with event: NSEvent) { pet?.endDrag(event) }
    override func rightMouseDown(with event: NSEvent) {
        guard let pet = pet else { return }
        NSMenu.popUpContextMenu(pet.contextMenu(), with: event, for: self)
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func accessibilityPerformPress() -> Bool { pet?.perform(.waving); return true }
}

final class DesktopPet: NSObject {
    let atlas: SpriteAtlas
    let panel: PetPanel
    let view = PetView(frame: .zero)
    let engine = AnimationEngine()
    weak var owner: AppDelegate?
    private var previousFrame: SpriteFrame?
    private var grab = NSPoint.zero
    private var dragStart = NSPoint.zero
    private var lastMouse = NSPoint.zero
    private var dragged = false
    private var dragging = false
    private var dragState: PetState?
    private var lastPointer = NSPoint.zero
    private var pointerActiveUntil: Double = 0
    private var nextWander: Double = 0
    private var wanderTarget: CGFloat?
    private var lastTick: Double = ProcessInfo.processInfo.systemUptime
    private var hoverGreeting = HoverGreeting()
    var visible: Bool { panel.isVisible }
    var isDragging: Bool { dragging }

    init(atlas: SpriteAtlas, owner: AppDelegate, index: Int) {
        self.atlas = atlas
        self.owner = owner
        panel = PetPanel(contentRect: NSRect(x: 0, y: 0, width: 192, height: 208),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()
        view.pet = self
        panel.contentView = view
        panel.title = atlas.name
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.animationBehavior = .none
        panel.isMovable = false
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.button)
        view.setAccessibilityLabel("\(atlas.name), desktop companion")
        view.setAccessibilityHelp("Hover to greet. Click to wave. Double-click to jump. Drag to move. Right-click for animations.")
        view.sprite = atlas.frame(SpriteFrame(row: 0, column: 0))
        let d = owner.defaults
        if d.object(forKey: "pet.\(atlas.id).x") != nil {
            panel.setFrameOrigin(NSPoint(x: d.double(forKey: "pet.\(atlas.id).x"), y: d.double(forKey: "pet.\(atlas.id).y")))
        } else { resetPosition(index: index) }
        applyOptions()
    }

    func applyOptions() {
        guard let owner = owner else { return }
        panel.level = owner.settings.alwaysOnTop ? .floating : .normal
        panel.ignoresMouseEvents = owner.settings.clickThrough
        panel.alphaValue = CGFloat(owner.settings.opacity)
        panel.collectionBehavior = owner.settings.allSpaces ? [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary] : [.fullScreenAuxiliary, .stationary]
        let origin = panel.frame.origin
        let scale = CGFloat(owner.miniSize(for: atlas.id))
        panel.setFrame(NSRect(x: origin.x, y: origin.y, width: 192 * scale, height: 208 * scale), display: true)
        clampToScreen()
    }

    func setVisible(_ show: Bool) {
        if show { panel.orderFrontRegardless() } else { panel.orderOut(nil); wanderTarget = nil }
    }

    func resetPosition(index: Int) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let f = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: f.maxX - CGFloat(index + 1) * 200 - 24, y: f.minY + 18))
        clampToScreen()
        savePosition()
    }

    func clampToScreen() {
        let frame = panel.frame
        let screen = NSScreen.screens.max(by: { intersectionArea($0.visibleFrame, frame) < intersectionArea($1.visibleFrame, frame) }) ?? NSScreen.main
        guard let screen = screen else { return }
        let safe = screen.visibleFrame
        let point = NSPoint(x: min(max(frame.minX, safe.minX), max(safe.minX, safe.maxX - frame.width)),
                            y: min(max(frame.minY, safe.minY), max(safe.minY, safe.maxY - frame.height)))
        panel.setFrameOrigin(point)
    }

    private func intersectionArea(_ a: NSRect, _ b: NSRect) -> CGFloat {
        let i = a.intersection(b)
        return i.isNull ? 0 : i.width * i.height
    }

    func applyRememberedPlacement(bundleID: String) {
        guard let owner = owner else { return }
        if let origin = AppPlacement.rememberedOrigin(defaults: owner.defaults, petID: atlas.id, bundleID: bundleID) {
            wanderTarget = nil
            panel.setFrameOrigin(origin)
        }
        applyOptions()
    }

    func savePosition() {
        guard let owner = owner else { return }
        let appBundleID = owner.settings.rememberPlacePerApp ? owner.placementAppBundleID() : nil
        AppPlacement.writeOrigin(defaults: owner.defaults, petID: atlas.id,
            origin: NSPoint(x: panel.frame.minX, y: panel.frame.minY),
            appBundleID: appBundleID, selfBundleID: Bundle.main.bundleIdentifier)
    }

    func beginDrag(_ event: NSEvent) {
        dragging = true; dragged = false; wanderTarget = nil
        let mouse = NSEvent.mouseLocation
        grab = NSPoint(x: mouse.x - panel.frame.minX, y: mouse.y - panel.frame.minY)
        dragStart = mouse; lastMouse = mouse
    }

    func drag(_ event: NSEvent) {
        let mouse = NSEvent.mouseLocation
        if hypot(mouse.x - dragStart.x, mouse.y - dragStart.y) > 3 { dragged = true }
        guard dragged else { return }
        let dx = mouse.x - lastMouse.x
        if owner?.settings.animateInteractions == true && abs(dx) > 0.5 { dragState = dx > 0 ? .runningRight : .runningLeft }
        panel.setFrameOrigin(NSPoint(x: mouse.x - grab.x, y: mouse.y - grab.y))
        lastMouse = mouse
        tick(ProcessInfo.processInfo.systemUptime)
    }

    func endDrag(_ event: NSEvent) {
        dragging = false; dragState = nil
        if dragged { clampToScreen(); savePosition(); engine.perform(.idle, now: ProcessInfo.processInfo.systemUptime, seconds: 0.25) }
        else if owner?.settings.animateInteractions == true { perform(event.clickCount >= 2 ? .jumping : .waving) }
    }

    func perform(_ state: PetState, seconds: Double? = nil) {
        wanderTarget = nil
        engine.perform(state, now: ProcessInfo.processInfo.systemUptime, seconds: seconds, speed: owner?.settings.speed ?? 1)
        tick(ProcessInfo.processInfo.systemUptime)
    }

    func tick(_ now: Double, mouseLocation: NSPoint? = nil) {
        guard let owner = owner, visible else { lastTick = now; return }
        let delta = min(0.1, max(0, now - lastTick)); lastTick = now
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let mouse = mouseLocation ?? NSEvent.mouseLocation
        let pointerX = Int((mouse.x - panel.frame.minX) / CGFloat(owner.miniSize(for: atlas.id)))
        let pointerTopY = 207 - Int((mouse.y - panel.frame.minY) / CGFloat(owner.miniSize(for: atlas.id)))
        let isHovering = panel.frame.contains(mouse) && atlas.isOpaque(SpriteFrame(row: 0, column: 0), x: pointerX, topY: pointerTopY)
        let shouldGreet = hoverGreeting.shouldGreet(isHovering: isHovering,
            isEnabled: owner.settings.greetOnHover,
            isBlocked: owner.settings.paused || reduced || owner.settings.clickThrough || dragging || wanderTarget != nil ||
                (engine.action != nil && !engine.isGreeting) || engine.baseState != .idle)
        if shouldGreet { engine.greet(owner.hoverReaction(for: atlas.id), now: now, speed: owner.settings.speed) }
        if hypot(mouse.x - lastPointer.x, mouse.y - lastPointer.y) > 1 {
            lastPointer = mouse; pointerActiveUntil = now + 1.3
        }
        if !dragging && owner.settings.wander && !owner.settings.paused && !reduced && engine.baseState == .idle && engine.action == nil {
            if nextWander == 0 { nextWander = now + Double.random(in: 12...22) }
            if now >= nextWander && wanderTarget == nil {
                let safe = (panel.screen ?? NSScreen.main)?.visibleFrame ?? panel.frame
                let displacement = CGFloat.random(in: 100...220) * (Bool.random() ? 1 : -1)
                wanderTarget = min(max(panel.frame.minX + displacement, safe.minX), safe.maxX - panel.frame.width)
            }
            if let target = wanderTarget {
                let dx = target - panel.frame.minX
                let step = min(abs(dx), CGFloat(delta) * 65)
                panel.setFrameOrigin(NSPoint(x: panel.frame.minX + (dx > 0 ? step : -step), y: panel.frame.minY))
                dragState = dx > 0 ? .runningRight : .runningLeft
                if abs(dx) < 1 { wanderTarget = nil; dragState = nil; nextWander = now + Double.random(in: 12...22); savePosition() }
            }
        } else if !dragging { wanderTarget = nil; dragState = nil; nextWander = 0 }
        var gaze: SpriteFrame?
        if atlas.hasLookDirections && owner.settings.followCursor && now < pointerActiveUntil && !panel.frame.contains(mouse) && !dragging && wanderTarget == nil {
            let center = NSPoint(x: panel.frame.midX, y: panel.frame.minY + panel.frame.height * 0.67)
            gaze = Gaze.frame(dx: Double(mouse.x - center.x), dy: Double(mouse.y - center.y))
        }
        let frame = engine.frame(now: now, drag: dragState, gaze: gaze, paused: owner.settings.paused, reducedMotion: reduced, animateIdle: owner.settings.animateIdle, loopActivities: owner.settings.loopActivities, speed: owner.settings.speed, animationInterval: owner.settings.animationInterval)
        if owner.settings.clickThrough { panel.ignoresMouseEvents = true }
        else if dragging { panel.ignoresMouseEvents = false }
        else if panel.frame.contains(mouse) {
            let x = Int((mouse.x - panel.frame.minX) / CGFloat(owner.miniSize(for: atlas.id)))
            let topY = 207 - Int((mouse.y - panel.frame.minY) / CGFloat(owner.miniSize(for: atlas.id)))
            panel.ignoresMouseEvents = !atlas.isOpaque(frame, x: x, topY: topY)
        } else { panel.ignoresMouseEvents = false }
        let status = frame.row < 9 ? PetState.allCases[frame.row].title : "Looking around"
        owner.updateStatus(atlas.id, status: status)
        if frame != previousFrame { view.sprite = atlas.frame(frame); previousFrame = frame }
    }

    func contextMenu() -> NSMenu {
        let menu = NSMenu(title: atlas.name)
        let title = NSMenuItem(title: atlas.name, action: nil, keyEquivalent: "")
        menu.addItem(title); menu.addItem(.separator())
        for state in PetState.allCases {
            let item = NSMenuItem(title: state.title, action: #selector(stateAction(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = state.rawValue
            item.state = engine.baseState == state && !state.transient ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Mini controls…", action: #selector(AppDelegate.showControls), keyEquivalent: "")
        settings.target = owner; menu.addItem(settings)
        let hide = NSMenuItem(title: "Hide \(atlas.name)", action: #selector(hidePet), keyEquivalent: "")
        hide.target = self; menu.addItem(hide)
        return menu
    }

    @objc private func stateAction(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let state = PetState(rawValue: raw) else { return }
        perform(state)
    }
    @objc private func hidePet() { owner?.setPetVisible(atlas.id, show: false) }
}
