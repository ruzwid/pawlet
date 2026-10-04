import SwiftUI
import AppKit

let petAccent = PawletTheme.accent
let petButtonAccent = PawletTheme.button

struct LibraryView: View {
    @ObservedObject var app: AppDelegate
    @State private var renaming = false
    @State private var proposedName = ""
    @State private var removing = false
    @State private var formatHelp = false
    @State private var search = ""

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
        .background(PawletTheme.canvas)
        .sheet(isPresented: $app.isCreating) { CreatePetView(app: app) }
        .sheet(isPresented: $formatHelp) { formatPage }
        .alert("Pawlet", isPresented: Binding(get: { app.message != nil }, set: { if !$0 { app.message = nil } })) {
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
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 10) {
                Image(nsImage: app.pawImage).resizable().renderingMode(.template).scaledToFit().frame(width: 23, height: 23)
                    .foregroundStyle(petAccent).padding(8).background(petAccent.opacity(0.10), in: RoundedRectangle(cornerRadius: 12)).accessibilityHidden(true)
                Text("Pawlet").font(.system(size: 22, weight: .bold, design: .rounded))
            }.padding(.top, 8)
            VStack(alignment: .leading, spacing: 6) {
                navigation("library", title: "Minis", symbol: "pawprint.fill")
                navigation("settings", title: "Settings", symbol: "slider.horizontal.3")
                navigation("about", title: "About Pawlet", symbol: "info.circle")
            }
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                Label("\(app.visibility.values.filter { $0 }.count) on desktop", systemImage: "desktopcomputer")
                    .font(.system(size: 12, weight: .medium))
                Button { app.settings.paused.toggle() } label: {
                    Label(app.settings.paused ? "Resume pets" : "Pause pets", systemImage: app.settings.paused ? "play" : "pause")
                        .font(.system(size: 11, weight: .medium)).frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(PawletActionStyle()).help("Pause or resume desktop animations")
            }.padding(10).background(PawletTheme.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
        }.padding(10).frame(width: 156).frame(maxHeight: .infinity).background(.thinMaterial)
    }
    private func navigation(_ id: String, title: String, symbol: String) -> some View {
        Button { app.section = id } label: {
            HStack(spacing: 9) {
                if id == "library" {
                    Image(nsImage: app.pawImage).resizable().renderingMode(.template).scaledToFit().frame(width: 16, height: 16).accessibilityHidden(true)
                } else {
                    Image(systemName: symbol).frame(width: 16).accessibilityHidden(true)
                }
                Text(title)
            }.font(.system(size: 13, weight: app.section == id ? .semibold : .medium))
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 10).padding(.vertical, 9)
                .foregroundStyle(app.section == id ? petAccent : Color.primary)
                .background(app.section == id ? petAccent.opacity(0.11) : .clear, in: RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain).accessibilityAddTraits(app.section == id ? .isSelected : []).accessibilityRemoveTraits(app.section == id ? [] : .isSelected)
    }

    private var filteredPets: [LibraryPet] {
        app.entries.filter { search.isEmpty || $0.manifest.name.localizedStandardContains(search) || $0.manifest.description.localizedStandardContains(search) }
    }
    private var libraryPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Text("Your minis").font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("\(app.entries.count)").font(.callout.monospacedDigit()).foregroundStyle(PawletTheme.secondary)
                }
                Spacer(minLength: 12)
                Button { app.revealLibrary() } label: { Label("Pets folder", systemImage: "folder") }.buttonStyle(PawletActionStyle())
                    .accessibilityLabel("Open pets folder").help("Open the library folder containing all your pets")
                Button { app.importPicker() } label: { Label("Import", systemImage: "square.and.arrow.down") }.buttonStyle(PawletActionStyle())
                Button { app.isCreating = true } label: { Label("Create", systemImage: "plus") }.buttonStyle(PawletActionStyle(prominent: true))
            }
            if app.entries.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "pawprint").font(.system(size: 44)).foregroundStyle(petAccent)
                    Text("Who's keeping you company?").font(.title2.weight(.semibold))
                    Text("Import a pet, or bring a new character to life.").foregroundStyle(PawletTheme.secondary)
                    Button("Import your first pet") { app.importPicker() }.buttonStyle(PawletActionStyle(prominent: true))
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass").foregroundStyle(PawletTheme.secondary).accessibilityHidden(true)
                            TextField("Find a mini", text: $search).textFieldStyle(.plain).font(.callout).accessibilityLabel("Search minis")
                            if !search.isEmpty {
                                Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.borderless).accessibilityLabel("Clear search")
                            }
                        }.padding(10).background(PawletTheme.surface, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(PawletTheme.border))
                        ScrollView {
                            if filteredPets.isEmpty {
                                Text("No minis found.").font(.callout).foregroundStyle(PawletTheme.secondary).padding(.top, 40)
                            } else {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 138), spacing: 12)], spacing: 12) {
                                    ForEach(filteredPets) { pet in petCard(pet) }
                                }.padding(2)
                            }
                        }
                    }.frame(maxWidth: .infinity).padding(.top, 2)
                    if let selected = app.selected {
                        PetInspectorView(app: app, preview: app.preview, pet: selected,
                            rename: { proposedName = selected.manifest.name; renaming = true }, remove: { removing = true }).frame(width: 368)
                    }
                }.frame(maxHeight: .infinity)
            }
            HStack {
                Button("Pet formats & sharing") { formatHelp = true }.buttonStyle(.link).font(.caption)
                Spacer()
                Label("Quiet by default", systemImage: "leaf").font(.caption).foregroundStyle(PawletTheme.secondary)
            }
        }.padding(24)
    }

    private func petCard(_ pet: LibraryPet) -> some View {
        let selected = app.selectedID == pet.id
        let visible = app.isVisible(pet.id)
        return VStack(alignment: .leading, spacing: 0) {
            Button { app.selectedID = pet.id } label: {
                VStack(alignment: .leading, spacing: 0) {
                    Image(nsImage: app.image(for: pet.id)).resizable().interpolation(.high).scaledToFit()
                        .frame(height: 132).frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(PawletTheme.stage.opacity(selected ? 1 : 0.5))
                    Text(pet.manifest.name).font(.system(size: 14, weight: .semibold, design: .rounded))
                        .lineLimit(1).padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 8)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("Select \(pet.manifest.name)")
                .accessibilityAddTraits(selected ? .isSelected : []).accessibilityRemoveTraits(selected ? [] : .isSelected)
            Button { app.togglePetVisibility(pet.id) } label: {
                Label(visible ? "Hide pet" : "Show pet", systemImage: visible ? "eye.slash" : "plus.circle")
                    .font(.system(size: 11, weight: .medium)).frame(maxWidth: .infinity).frame(height: 28)
                    .foregroundStyle(visible ? petAccent : Color.primary)
                    .background(visible ? petAccent.opacity(0.10) : PawletTheme.canvas, in: RoundedRectangle(cornerRadius: 8))
            }.buttonStyle(.plain).accessibilityLabel("\(visible ? "Hide" : "Show") \(pet.manifest.name) on desktop")
                .help("Show or hide \(pet.manifest.name) with one click; keep the current preview selected.")
                .padding(.horizontal, 10).padding(.bottom, 10)
        }.background(PawletTheme.surface).clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? petAccent : PawletTheme.border, lineWidth: selected ? 1.5 : 1))
    }

    private var settingsPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Make yourself at home.").font(.system(size: 28, weight: .bold, design: .rounded))
            Text("Small companions. Just the way you like them.").foregroundStyle(PawletTheme.secondary)
            Form {
                Section("Hello & interactions") {
                    Toggle("React when I hover", isOn: $app.settings.greetOnHover)
                    Picker("Default hover reaction", selection: $app.settings.hoverReaction) {
                        ForEach(HoverReaction.allCases, id: \.rawValue) { reaction in Text(reaction.title).tag(reaction) }
                    }.disabled(!app.settings.greetOnHover)
                    Text("Each pet can have its own reaction in the library. Hover plays once and always ignores the time between animations.").font(.caption).foregroundStyle(PawletTheme.secondary)
                    Toggle("Animate clicks and drags", isOn: $app.settings.animateInteractions)
                }
                Section("Movement & rest") {
                    Toggle("Animate while idle", isOn: $app.settings.animateIdle)
                    Toggle("Follow the cursor", isOn: $app.settings.followCursor)
                    Toggle("Wander occasionally", isOn: $app.settings.wander)
                    Toggle("Loop working, waiting and review animations", isOn: $app.settings.loopActivities)
                    LabeledContent("Time between animations") {
                        Slider(value: $app.settings.animationInterval, in: 0...MotionConstants.MAX_INTERVAL_SECONDS, step: 1)
                        Text(app.settings.animationInterval == 0 ? "None" : "\(Int(app.settings.animationInterval)) s").monospacedDigit().frame(width: 45)
                    }
                    Text("Rest after each idle or activity loop. Zero plays continuously; clicks and greetings still respond immediately.").font(.caption).foregroundStyle(.secondary)
                    Toggle("Pause all animations", isOn: $app.settings.paused)
                    LabeledContent("Animation speed") { Slider(value: $app.settings.speed, in: 0.5...1.5); Text("\(Int(app.settings.speed * 100))%").monospacedDigit().frame(width: 45) }
                    Text("Idle movement is off by default. Your Mac's Reduce Motion setting always takes priority.").font(.caption).foregroundStyle(.secondary)
                }
                Section("On your desktop") {
                    LabeledContent("Pet size") { Slider(value: $app.settings.size, in: MotionConstants.MIN_PET_SCALE...MotionConstants.MAX_PET_SCALE, step: 0.01); Text("\(Int((app.settings.size * 100).rounded()))%").monospacedDigit().frame(width: 45) }
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
            Image(nsImage: app.pawImage).resizable().renderingMode(.template).scaledToFit().frame(width: 44, height: 44).foregroundStyle(petAccent).accessibilityHidden(true)
            Text("Pawlet").font(.system(size: 32, weight: .bold, design: .rounded))
            Text("Your characters. Your desktop.").font(.title3)
            Text("An offline Mac app for collecting and enjoying animated companions. Add a pet pack, import a compatible sprite sheet, or make something new with Codex.").foregroundStyle(.secondary)
            Divider()
            Text("The app works without Codex. Codex is only used when you choose to create new artwork.")
            Text("No accounts, telemetry or network listener. Imported pets are image and metadata files; they don't run code.").font(.callout).foregroundStyle(.secondary)
            Button("Learn about pet packs") { formatHelp = true }
            Text("Version 0.5.2 · macOS 13+").font(.caption).foregroundStyle(.secondary)
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
            Text("Import also accepts a Codex pet folder or ZIP with pet.json and its sprite sheet. Use Share → Export for Codex to save the same artwork in that format, or use the folder button at the top of the library to browse all your pets.").font(.callout)
            Text("v2: 1536 × 2288, 192 × 208 cells, 9 animations + 16 gaze poses.\nv1: 1536 × 1872, 9 animations without gaze tracking.").font(.callout).foregroundStyle(.secondary)
            Text("A regular photo is a creation reference, not an animated pet. Use Create to turn it into one.").font(.callout)
            HStack { Spacer(); Button("Got it") { formatHelp = false }.keyboardShortcut(.defaultAction) }
        }.padding(28).frame(width: 470)
    }
}
