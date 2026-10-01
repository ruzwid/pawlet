import AppKit
import SwiftUI
import ServiceManagement
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let defaults: UserDefaults = CommandLine.arguments.contains("--ui-smoke-test")
        ? UserDefaults(suiteName: "com.ruzwid.pawlet.tests")! : .standard
    @Published var entries: [LibraryPet] = []
    @Published var selectedID: String?
    @Published var statuses: [String: String] = [:]
    @Published var visibility: [String: Bool] = [:]
    @Published var section = "library"
    @Published var message: String?
    @Published var settings = AppSettings() { didSet { saveSettings() } }
    @Published var isCreating = false
    @Published var loginEnabled = false
    var library: PetLibrary!
    var pets: [DesktopPet] = []
    var statusItem: NSStatusItem!
    var controls: NSWindow?
    var timer: Timer?
    var thumbnails: [String: NSImage] = [:]
    lazy var pawImage: NSImage = {
        let image = Bundle.main.url(forResource: "PawMark", withExtension: "png").flatMap(NSImage.init(contentsOf:))
            ?? NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Pawlet")!
        image.isTemplate = true; image.size = NSSize(width: 18, height: 18)
        return image
    }()
    private var ready = false
    private var pendingURLs: [URL] = []
    private var pendingImports: [URL] = []
    var selected: LibraryPet? { entries.first { $0.id == selectedID } }

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(receiveURL(_:reply:)),
            forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        if !CommandLine.arguments.contains("--ui-smoke-test"), defaults.object(forKey: "settings") == nil,
           let previous = defaults.persistentDomain(forName: "community.desktoppets.app") {
            for (key, value) in previous where key == "settings" || key.hasPrefix("pet.") || key.hasPrefix("removed.") { defaults.set(value, forKey: key) }
        }
        if let data = defaults.data(forKey: "settings"), let saved = try? JSONDecoder().decode(AppSettings.self, from: data) { settings = saved }
        do {
            let support: URL
            if let i = CommandLine.arguments.firstIndex(of: "--ui-smoke-test"), i + 1 < CommandLine.arguments.count {
                support = URL(fileURLWithPath: CommandLine.arguments[i + 1], isDirectory: true).appendingPathComponent("test-library")
                settings = AppSettings()
            } else {
                let applicationSupport = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                support = applicationSupport.appendingPathComponent("Pawlet/Library", isDirectory: true)
                let previousLibrary = applicationSupport.appendingPathComponent("Desktop Pets/Library", isDirectory: true)
                if !FileManager.default.fileExists(atPath: support.path), FileManager.default.fileExists(atPath: previousLibrary.path) {
                    try FileManager.default.createDirectory(at: support.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try FileManager.default.copyItem(at: previousLibrary, to: support)
                }
            }
            library = try PetLibrary(root: support)
            if let resources = Bundle.main.resourceURL {
                let removed = Set(defaults.dictionaryRepresentation().compactMap { key, value in
                    key.hasPrefix("removed.") && (value as? Bool == true) ? String(key.dropFirst(8)) : nil
                })
                try library.seed(from: resources.appendingPathComponent("Pets"), excluding: removed)
            }
            reloadLibrary()
        } catch { showError(error); NSApp.terminate(nil); return }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = pawImage
        statusItem.button?.toolTip = "Pawlet"
        applyAppearance(); buildMenus()
        ready = true
        for entry in entries where defaults.object(forKey: "pet.\(entry.id).visible") == nil {
            defaults.set(entry.id == "mochi-sample", forKey: "pet.\(entry.id).visible")
        }
        for entry in entries where defaults.bool(forKey: "pet.\(entry.id).visible") { setPetVisible(entry.id, show: true) }
        for url in pendingURLs { handleURL(url) }; pendingURLs.removeAll()
        for url in pendingImports { importPet(url) }; pendingImports.removeAll()
        startTimer()
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
        loginEnabled = SMAppService.mainApp.status == .enabled
        if !defaults.bool(forKey: "didLaunch") || CommandLine.arguments.contains("--show-controls") { showControls(); defaults.set(true, forKey: "didLaunch") }
        if let i = CommandLine.arguments.firstIndex(of: "--import"), i + 1 < CommandLine.arguments.count { importPet(URL(fileURLWithPath: CommandLine.arguments[i + 1])) }
        if let i = CommandLine.arguments.firstIndex(of: "--url"), i + 1 < CommandLine.arguments.count, let url = URL(string: CommandLine.arguments[i + 1]) { handleURL(url) }
        if let i = CommandLine.arguments.firstIndex(of: "--ui-smoke-test"), i + 1 < CommandLine.arguments.count {
            runUISmokeTest(URL(fileURLWithPath: CommandLine.arguments[i + 1], isDirectory: true))
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { pets.forEach { $0.savePosition() }; timer?.invalidate() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showControls(); return true }
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        filenames.forEach { importPet(URL(fileURLWithPath: $0)) }
        sender.reply(toOpenOrPrint: .success)
    }
    func startTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            let now = ProcessInfo.processInfo.systemUptime; self?.pets.forEach { $0.tick(now) }
        }
        t.tolerance = 0.01; RunLoop.main.add(t, forMode: .common); timer = t
    }
    @objc func willSleep() { timer?.invalidate(); pets.forEach { $0.savePosition() } }
    @objc func didWake() { pets.forEach { $0.clampToScreen() }; startTimer() }
    @objc func screensChanged() { pets.forEach { $0.clampToScreen() } }

    func reloadLibrary() {
        entries = library.list()
        thumbnails = [:]
        for entry in entries { thumbnails[entry.id] = try? SpriteAtlas.thumbnail(directory: entry.directory) }
        if !entries.contains(where: { $0.id == selectedID }) { selectedID = entries.first?.id }
        if !library.issues.isEmpty { message = library.issues.joined(separator: "\n") }
    }
    func image(for id: String) -> NSImage { thumbnails[id] ?? NSImage(size: NSSize(width: 192, height: 208)) }
    func isVisible(_ id: String) -> Bool { visibility[id] ?? false }
    func setPetVisible(_ id: String, show: Bool) {
        guard let entry = entries.first(where: { $0.id == id }) else { return }
        if show && pets.first(where: { $0.atlas.id == id }) == nil {
            guard pets.filter({ $0.visible }).count < 6 else { message = "You can show up to six pets at once. Hide one to make room."; return }
            do {
                let pet = DesktopPet(atlas: try SpriteAtlas(manifest: entry.manifest, directory: entry.directory), owner: self, index: pets.count)
                pets.append(pet)
            } catch { message = error.localizedDescription; return }
        }
        if let pet = pets.first(where: { $0.atlas.id == id }) {
            if show && !pet.visible && pets.filter({ $0.visible }).count >= 6 { message = "You can show up to six pets at once. Hide one to make room."; return }
            pet.setVisible(show)
            if !show { pets.removeAll { $0.atlas.id == id }; pet.savePosition(); pet.panel.close() }
        }
        visibility[id] = show; defaults.set(show, forKey: "pet.\(id).visible")
        if ready { buildMenus() }
    }
    func updateStatus(_ id: String, status: String) { if statuses[id] != status { statuses[id] = status } }
    func perform(_ state: PetState, id: String? = nil, seconds: Double? = nil) {
        if let id = id, !isVisible(id) { setPetVisible(id, show: true) }
        pets.filter { $0.visible && (id == nil || $0.atlas.id == id) }.forEach { $0.perform(state, seconds: seconds) }
    }
    func saveSettings() {
        guard ready else { return }
        if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: "settings") }
        pets.forEach { $0.applyOptions() }; applyAppearance(); buildMenus()
    }
    func applyAppearance() {
        NSApp.setActivationPolicy(settings.showDockIcon ? .regular : .accessory)
        NSApp.appearance = settings.appearance == "light" ? NSAppearance(named: .aqua) : settings.appearance == "dark" ? NSAppearance(named: .darkAqua) : nil
    }
    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginEnabled = SMAppService.mainApp.status == .enabled
            if SMAppService.mainApp.status == .requiresApproval { message = "Approve Pawlet in System Settings → General → Login Items." }
        } catch { message = "Login setting couldn't be changed: \(error.localizedDescription)" }
    }

    func importPicker() {
        let panel = NSOpenPanel(); panel.title = "Add a pet"; panel.message = "Choose a .petpack or a complete PNG sprite sheet."
        panel.allowedContentTypes = [UTType(filenameExtension: "petpack") ?? .data, .png, .zip]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { importPet(url) }
    }
    func importPet(_ url: URL) {
        guard ready else { pendingImports.append(url); return }
        do { let pet = try library.importFile(url); reloadLibrary(); selectedID = pet.id; section = "library"; setPetVisible(pet.id, show: true) }
        catch { message = error.localizedDescription }
    }
    func exportSelected() {
        guard let selected = selected else { return }
        let panel = NSSavePanel(); panel.title = "Share \(selected.manifest.name)"
        panel.nameFieldStringValue = selected.manifest.name + ".petpack"
        panel.allowedContentTypes = [UTType(filenameExtension: "petpack") ?? .data]
        if panel.runModal() == .OK, let url = panel.url {
            do { try PetArchive.export(selected, to: url) } catch { message = error.localizedDescription }
        }
    }
    func renameSelected(_ name: String) {
        guard let selected = selected else { return }
        do {
            let showing = isVisible(selected.id)
            try library.rename(selected, to: name)
            setPetVisible(selected.id, show: false); reloadLibrary(); if showing { setPetVisible(selected.id, show: true) }
        } catch { message = error.localizedDescription }
    }
    func removeSelected() {
        guard let selected = selected else { return }
        do {
            setPetVisible(selected.id, show: false)
            try FileManager.default.trashItem(at: selected.directory, resultingItemURL: nil)
            defaults.set(true, forKey: "removed.\(selected.id)")
            reloadLibrary()
        } catch { message = error.localizedDescription }
    }
    func revealLibrary() { NSWorkspace.shared.open(library.root) }
    @objc func resetPositions() { for (index, pet) in pets.enumerated() { pet.resetPosition(index: index) } }

    func item(_ title: String, action: Selector, object: String? = nil, checked: Bool? = nil, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key); item.target = self; item.representedObject = object
        if let checked = checked { item.state = checked ? .on : .off }; return item
    }
    func buildMenus() {
        guard statusItem != nil else { return }
        let menu = NSMenu()
        menu.addItem(item("Open pet library…", action: #selector(showControls), key: "l"))
        menu.addItem(item("Add a pet…", action: #selector(importMenu)))
        menu.addItem(item("Create with Codex…", action: #selector(createMenu)))
        menu.addItem(.separator())
        for entry in entries { menu.addItem(item("Show \(entry.manifest.name)", action: #selector(togglePetMenu(_:)), object: entry.id, checked: isVisible(entry.id))) }
        menu.addItem(.separator())
        menu.addItem(item("Pause animations", action: #selector(pauseMenu), checked: settings.paused))
        menu.addItem(item("Settings…", action: #selector(settingsMenu), key: ","))
        menu.addItem(item("Bring pets back to this screen", action: #selector(resetPositions)))
        menu.addItem(.separator()); menu.addItem(item("Quit Pawlet", action: #selector(quit), key: "q"))
        statusItem.menu = menu
        let main = NSMenu(), appItem = NSMenuItem(title: "Pawlet", action: nil, keyEquivalent: ""), appMenu = NSMenu()
        appMenu.addItem(item("Pet library…", action: #selector(showControls), key: "l"))
        appMenu.addItem(item("Settings…", action: #selector(settingsMenu), key: ","))
        appMenu.addItem(.separator()); appMenu.addItem(item("Quit Pawlet", action: #selector(quit), key: "q"))
        appItem.submenu = appMenu; main.addItem(appItem)
        let edit = NSMenu(title: "Edit"), editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        for (title, selector, key) in [("Cut", #selector(NSText.cut(_:)), "x"), ("Copy", #selector(NSText.copy(_:)), "c"),
            ("Paste", #selector(NSText.paste(_:)), "v"), ("Select All", #selector(NSText.selectAll(_:)), "a")] { edit.addItem(NSMenuItem(title: title, action: selector, keyEquivalent: key)) }
        editItem.submenu = edit; main.addItem(editItem); NSApp.mainMenu = main
    }
    @objc func togglePetMenu(_ sender: NSMenuItem) { if let id = sender.representedObject as? String { setPetVisible(id, show: !isVisible(id)) } }
    @objc func pauseMenu() { settings.paused.toggle() }
    @objc func importMenu() { showControls(); importPicker() }
    @objc func createMenu() { showControls(); isCreating = true }
    @objc func settingsMenu() { section = "settings"; showControls() }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func showControls() {
        if controls == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 940, height: 680), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Pawlet"; window.minSize = NSSize(width: 820, height: 580); window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: LibraryView(app: self)); window.center(); controls = window
        }
        controls?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func showError(_ error: Error) {
        let alert = NSAlert(); alert.messageText = "Pawlet couldn't open"; alert.informativeText = error.localizedDescription; alert.runModal()
    }
    @objc func receiveURL(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        if let text = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue, let url = URL(string: text) { handleURL(url) }
    }
    func handleURL(_ url: URL) {
        guard ready else { pendingURLs.append(url); return }
        guard ["pawlet", "desktoppets"].contains(url.scheme?.lowercased() ?? "") else { return }
        if url.host == "controls" { showControls(); return }
        guard let command = StateCommand.parse(url) else { return }
        let targets = entries.filter { command.pet == "both" || command.pet == "all" || $0.id.lowercased() == command.pet || $0.manifest.name.lowercased() == command.pet }
        for pet in targets { perform(command.state, id: pet.id, seconds: command.seconds) }
    }

    func runUISmokeTest(_ folder: URL) {
        showControls()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self = self else { return }
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let entry = self.entries[0]
                self.setPetVisible(entry.id, show: true)
                let pet = self.pets.first { $0.atlas.id == entry.id }!
                let now = ProcessInfo.processInfo.systemUptime
                let stillA = pet.engine.frame(now: now, animateIdle: false)
                let stillB = pet.engine.frame(now: now + 20, animateIdle: false)
                guard stillA == stillB else { throw PetLibraryError.invalid("Calm idle changed frames") }
                let pack = folder.appendingPathComponent("export-test.petpack")
                try PetArchive.export(entry, to: pack)
                let unpacked = try PetArchive.unpack(pack)
                defer { try? FileManager.default.removeItem(at: unpacked) }
                _ = try SpriteAtlas(manifest: try self.library.readManifest(unpacked), directory: unpacked)
                self.settings.size = 1.25
                guard abs(pet.panel.frame.width - 240) < 0.01 else { throw PetLibraryError.invalid("Size control") }
                self.settings.size = 1
                self.handleURL(URL(string: "pawlet://state?pet=\(entry.id)&state=waiting&seconds=5")!)
                guard pet.engine.action == .waiting else { throw PetLibraryError.invalid("Dynamic pet command") }
                pet.engine.reset()
                let outsidePet = NSPoint(x: pet.panel.frame.minX - 20, y: pet.panel.frame.minY - 20)
                let overPet = NSPoint(x: pet.panel.frame.minX + 96, y: pet.panel.frame.minY + 87)
                pet.tick(now, mouseLocation: outsidePet)
                pet.tick(now + 0.01, mouseLocation: overPet)
                if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                    guard pet.engine.action == .waving else { throw PetLibraryError.invalid("Hover didn't wave") }
                }
                pet.tick(now + 2, mouseLocation: overPet)
                guard pet.engine.action == nil else { throw PetLibraryError.invalid("Stationary hover repeated") }
                pet.engine.reset()
                self.settings.paused = true
                pet.tick(now + 12, mouseLocation: outsidePet)
                pet.tick(now + 13, mouseLocation: overPet)
                guard pet.engine.action == nil else { throw PetLibraryError.invalid("Paused hover animated") }
                self.settings.paused = false
                self.settings.greetOnHover = false
                pet.tick(now + 24, mouseLocation: outsidePet)
                pet.tick(now + 25, mouseLocation: overPet)
                guard pet.engine.action == nil else { throw PetLibraryError.invalid("Disabled hover animated") }
                self.settings.greetOnHover = true
                pet.tick(now)
                self.updateStatus(entry.id, status: "Idle")
                try self.captureOwnView(self.controls?.contentView, to: folder.appendingPathComponent("library.png"))
                let report: [String: Any] = ["ok": true, "calm_idle_stays_still": true, "pack_export_import": true,
                    "dynamic_pet_url": true, "native_window_and_size": true, "library_count": self.entries.count,
                    "menu_bar": self.statusItem.button != nil, "hover_wave": true,
                    "stationary_hover_does_not_repeat": true, "paused_and_disabled_hover": true]
                self.section = "settings"
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    do {
                        try self.captureOwnView(self.controls?.contentView, to: folder.appendingPathComponent("settings.png"))
                        self.section = "library"; self.isCreating = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            do {
                                guard let sheet = self.controls?.sheets.first else { throw PetLibraryError.invalid("Creation sheet didn't open") }
                                try self.captureOwnView(sheet.contentView, to: folder.appendingPathComponent("create.png"))
                                var finalReport = report
                                finalReport["settings_and_creation_sheet"] = true
                                try JSONSerialization.data(withJSONObject: finalReport, options: [.prettyPrinted, .sortedKeys]).write(to: folder.appendingPathComponent("ui-test.json"))
                                self.isCreating = false
                                self.controls?.endSheet(sheet); sheet.orderOut(nil)
                                print("Native UI, settings, creation sheet and pet-library checks passed")
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { NSApp.terminate(nil) }
                            } catch { fputs("UI test failed: \(error.localizedDescription)\n", stderr); exit(1) }
                        }
                    } catch { fputs("UI test failed: \(error.localizedDescription)\n", stderr); exit(1) }
                }
            } catch { fputs("UI test failed: \(error.localizedDescription)\n", stderr); exit(1) }
        }
    }
    func captureOwnView(_ view: NSView?, to url: URL) throws {
        guard let view = view, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw PetLibraryError.invalid("Couldn't capture test view") }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw PetLibraryError.invalid("Couldn't encode test screenshot") }
        try data.write(to: url)
    }
}
