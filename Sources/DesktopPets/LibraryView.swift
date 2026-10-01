import SwiftUI
import AppKit

let petAccent = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(red: 0.50, green: 0.72, blue: 0.88, alpha: 1)
        : NSColor(red: 0.24, green: 0.43, blue: 0.57, alpha: 1)
})
let petButtonAccent = Color(red: 0.24, green: 0.43, blue: 0.57)

struct LibraryView: View {
    @ObservedObject var app: AppDelegate
    @State private var renaming = false
    @State private var proposedName = ""
    @State private var removing = false
    @State private var formatHelp = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            Group {
                if app.section == "settings" { settingsPage }
                else if app.section == "about" { aboutPage }
                else { libraryPage }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .tint(petAccent)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $app.isCreating) { CreatePetView(app: app) }
        .sheet(isPresented: $formatHelp) { formatPage }
        .alert("Desktop Pets", isPresented: Binding(get: { app.message != nil }, set: { if !$0 { app.message = nil } })) {
            Button("OK") { app.message = nil }
        } message: { Text(app.message ?? "") }
        .alert("Rename pet", isPresented: $renaming) {
            TextField("Pet name", text: $proposedName)
            Button("Cancel", role: .cancel) {}
            Button("Save") { app.renameSelected(proposedName) }
        }
        .alert("Move this pet to Trash?", isPresented: $removing) {
            Button("Cancel", role: .cancel) {}
            Button("Move to Trash", role: .destructive) { app.removeSelected() }
        } message: { Text("The pet's library files will go to Finder's Trash, where you can recover them.") }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 9) {
                Image(systemName: "pawprint.fill").font(.title2).foregroundStyle(petAccent)
                Text("Desktop\nPets").font(.system(size: 18, weight: .bold, design: .rounded))
            }.padding(.top, 12)
            VStack(spacing: 5) {
                navigation("library", title: "Pet library", symbol: "square.grid.2x2")
                navigation("settings", title: "Settings", symbol: "slider.horizontal.3")
                navigation("about", title: "About", symbol: "info.circle")
            }
            Spacer()
            VStack(alignment: .leading, spacing: 7) {
                Label("\(app.visibility.values.filter { $0 }.count) on desktop", systemImage: "circle.fill")
                    .font(.caption).foregroundStyle(.secondary)
                Text("A little company.\nAt your own pace.").font(.caption).foregroundStyle(.secondary)
            }.padding(.bottom, 10)
        }.padding(.horizontal, 16).padding(.vertical, 18).frame(width: 154)
            .frame(maxHeight: .infinity).background(.thinMaterial)
    }
    private func navigation(_ id: String, title: String, symbol: String) -> some View {
        Button { app.section = id } label: {
            Label(title, systemImage: symbol).font(.system(size: 13, weight: app.section == id ? .semibold : .regular))
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 10).padding(.vertical, 11)
                .background(app.section == id ? petAccent.opacity(0.13) : .clear, in: RoundedRectangle(cornerRadius: 9))
        }.buttonStyle(.plain).accessibilityAddTraits(app.section == id ? .isSelected : [])
    }

    private var libraryPage: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Your pets").font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("Choose your company. Add something new.").foregroundStyle(.secondary)
                }
                Spacer()
                Button { app.importPicker() } label: { Label("Import", systemImage: "square.and.arrow.down") }
                Button { app.isCreating = true } label: { Label("Create", systemImage: "plus") }.buttonStyle(.borderedProminent).tint(petButtonAccent).foregroundStyle(.white)
            }
            if app.entries.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "pawprint").font(.system(size: 44)).foregroundStyle(petAccent)
                    Text("Make yourself some company.").font(.title2.weight(.semibold))
                    Text("Import a pet pack, or create a character with Codex.").foregroundStyle(.secondary)
                    Button("Import a pet") { app.importPicker() }.buttonStyle(.borderedProminent).tint(petButtonAccent).foregroundStyle(.white)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(alignment: .top, spacing: 22) {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
                            ForEach(app.entries) { pet in petCard(pet) }
                        }.padding(2)
                    }.frame(maxWidth: .infinity)
                    if let selected = app.selected { inspector(selected).frame(width: 260) }
                }.frame(maxHeight: .infinity)
            }
            HStack {
                Button("What is a pet pack?") { formatHelp = true }.buttonStyle(.link)
                Spacer()
                Text("Quiet by default").font(.caption).foregroundStyle(.secondary)
            }
        }.padding(26)
    }

    private func petCard(_ pet: LibraryPet) -> some View {
        Button { app.selectedID = pet.id } label: {
            VStack(spacing: 8) {
                Image(nsImage: app.image(for: pet.id)).resizable().interpolation(.high).scaledToFit()
                    .frame(height: 136).padding(.top, 10)
                HStack {
                    Text(pet.manifest.name).font(.system(size: 14, weight: .semibold, design: .rounded)).lineLimit(1)
                    Spacer()
                    if app.isVisible(pet.id) { Image(systemName: "checkmark.circle.fill").foregroundStyle(petAccent).accessibilityLabel("On desktop") }
                }
                Text(app.isVisible(pet.id) ? "On your desktop" : "In your library").font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.padding(12).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(app.selectedID == pet.id ? petAccent : Color.primary.opacity(0.08), lineWidth: app.selectedID == pet.id ? 2 : 1))
        }.buttonStyle(.plain).accessibilityLabel("Select \(pet.manifest.name)")
    }

    private func inspector(_ pet: LibraryPet) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 18).fill(petAccent.opacity(0.08))
                Capsule().fill(petAccent.opacity(0.12)).frame(width: 115, height: 4).padding(.bottom, 14)
                Image(nsImage: app.image(for: pet.id)).resizable().scaledToFit().frame(width: 184, height: 200).padding(.bottom, 19)
            }.frame(height: 235)
            VStack(alignment: .leading, spacing: 5) {
                Text(pet.manifest.name).font(.system(size: 24, weight: .bold, design: .rounded))
                Text(pet.manifest.description).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Toggle("Show on desktop", isOn: Binding(get: { app.isVisible(pet.id) }, set: { app.setPetVisible(pet.id, show: $0) }))
                .toggleStyle(.switch)
            HStack {
                Label(app.isVisible(pet.id) ? (app.statuses[pet.id] ?? "Idle") : "Hidden", systemImage: "circle.dotted")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button { app.perform(.idle, id: pet.id) } label: { Image(systemName: "arrow.counterclockwise") }
                    .help("Return to idle")
            }
            HStack {
                Button("Wave") { app.perform(.waving, id: pet.id) }
                Button("Jump") { app.perform(.jumping, id: pet.id) }
                Menu("More") {
                    ForEach(PetState.allCases, id: \.rawValue) { state in Button(state.title) { app.perform(state, id: pet.id) } }
                }
            }
            Divider()
            HStack {
                Button { app.exportSelected() } label: { Label("Share", systemImage: "square.and.arrow.up") }
                Menu {
                    Button("Rename…") { proposedName = pet.manifest.name; renaming = true }
                    Button("Move to Trash…", role: .destructive) { removing = true }
                } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 28).accessibilityLabel("Pet options")
                Spacer()
            }
        }
    }

    private var settingsPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("At your own pace").font(.system(size: 28, weight: .bold, design: .rounded))
            Text("Keep them still, or invite a little movement.").foregroundStyle(.secondary)
            Form {
                Section("Movement") {
                    Toggle("Animate while idle", isOn: $app.settings.animateIdle)
                    Toggle("Follow the cursor", isOn: $app.settings.followCursor)
                    Toggle("Wander occasionally", isOn: $app.settings.wander)
                    Toggle("Loop working, waiting and review animations", isOn: $app.settings.loopActivities)
                    Toggle("Animate clicks and drags", isOn: $app.settings.animateInteractions)
                    Toggle("Pause all animations", isOn: $app.settings.paused)
                    LabeledContent("Animation speed") { Slider(value: $app.settings.speed, in: 0.5...1.5); Text("\(Int(app.settings.speed * 100))%").monospacedDigit().frame(width: 45) }
                    Text("Idle movement is off by default. Your Mac's Reduce Motion setting always takes priority.").font(.caption).foregroundStyle(.secondary)
                }
                Section("On your desktop") {
                    LabeledContent("Pet size") { Slider(value: $app.settings.size, in: 0.65...1.75); Text("\(Int(app.settings.size * 100))%").monospacedDigit().frame(width: 45) }
                    LabeledContent("Opacity") { Slider(value: $app.settings.opacity, in: 0.3...1); Text("\(Int(app.settings.opacity * 100))%").monospacedDigit().frame(width: 45) }
                    Toggle("Stay above other windows", isOn: $app.settings.alwaysOnTop)
                    Toggle("Show on all desktop Spaces", isOn: $app.settings.allSpaces)
                    Toggle("Let clicks pass through the pets", isOn: $app.settings.clickThrough)
                    Button("Bring pets back to this screen") { app.resetPositions() }
                }
                Section("App") {
                    Toggle("Show the Dock icon", isOn: $app.settings.showDockIcon)
                    Toggle("Open at login", isOn: Binding(get: { app.loginEnabled }, set: { app.setLogin($0) }))
                    Picker("Appearance", selection: $app.settings.appearance) { Text("System").tag("system"); Text("Light").tag("light"); Text("Dark").tag("dark") }
                    Button("Show pet files in Finder") { app.revealLibrary() }
                    Button("Restore quiet defaults") { app.settings = AppSettings() }
                }
            }.formStyle(.grouped)
        }.padding(26)
    }

    private var aboutPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "pawprint.fill").font(.system(size: 44)).foregroundStyle(petAccent)
            Text("Desktop Pets").font(.system(size: 32, weight: .bold, design: .rounded))
            Text("Your characters. Your desktop.").font(.title3)
            Text("An offline Mac app for collecting and enjoying animated companions. Add a pet pack, import a compatible sprite sheet, or make something new with Codex.").foregroundStyle(.secondary)
            Divider()
            Text("The app works without Codex. Codex is only used when you choose to create new artwork.")
            Text("No accounts, telemetry or network listener. Imported pets are image and metadata files; they don't run code.").font(.callout).foregroundStyle(.secondary)
            Button("Learn about pet packs") { formatHelp = true }
            Text("Version 0.2.0 · macOS 13+").font(.caption).foregroundStyle(.secondary)
            Spacer()
        }.padding(36).frame(maxWidth: .infinity, alignment: .leading)
    }

    private var formatPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("A pet in one file").font(.title.weight(.bold))
            Text("A .petpack is a ZIP with two files at its root:")
            Text("manifest.json\nspritesheet.png").font(.system(.body, design: .monospaced)).padding(16)
                .frame(maxWidth: .infinity, alignment: .leading).background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            Text("The JSON names the pet and its sprite format. The transparent PNG holds every pose in a fixed grid. Preview images are optional.")
            Text("v2: 1536 × 2288, 192 × 208 cells, 9 animations + 16 gaze poses.\nv1: 1536 × 1872, 9 animations without gaze tracking.").font(.callout).foregroundStyle(.secondary)
            Text("A regular photo is a creation reference, not an animated pet. Use Create to turn it into one.").font(.callout)
            HStack { Spacer(); Button("Got it") { formatHelp = false }.keyboardShortcut(.defaultAction) }
        }.padding(28).frame(width: 470)
    }
}
