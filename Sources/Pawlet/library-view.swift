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
    @FocusState private var searchFocused: Bool

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
        .foregroundStyle(PawletTheme.ink)
        .background(PawletTheme.canvas)
        .sheet(isPresented: $app.isCreating) { CreatePetView(app: app) }
        .sheet(isPresented: $formatHelp) { formatPage }
        .alert("Pawlet", isPresented: Binding(get: { app.message != nil }, set: { if !$0 { app.message = nil } })) {
            Button("OK") { app.message = nil }
        } message: { Text(app.message ?? "") }
        .alert("Rename mini", isPresented: $renaming) {
            TextField("Mini name", text: $proposedName)
            Button("Cancel", role: .cancel) {}
            Button("Save") { app.renameSelected(proposedName) }
        }
        .alert("Move this mini to Trash?", isPresented: $removing) {
            Button("Cancel", role: .cancel) {}
            Button("Move to Trash", role: .destructive) { app.removeSelected() }
        } message: { Text("The mini's library files will go to Finder's Trash, where you can recover them.") }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 10) {
                Image(nsImage: app.pawImage).resizable().renderingMode(.template).scaledToFit().frame(width: 23, height: 23)
                    .foregroundStyle(petAccent).padding(8).background(petAccent.opacity(0.10), in: PawletTheme.roundedShape(12)).accessibilityHidden(true)
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
                Button { app.setAllMinisVisible(!app.hasVisibleMinis) } label: {
                    Label(app.hasVisibleMinis ? "Hide all minis" : "Show all minis", systemImage: app.hasVisibleMinis ? "eye.slash" : "eye")
                        .font(.system(size: 11, weight: .medium)).lineLimit(1).minimumScaleFactor(0.85).frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(PawletActionStyle(compact: true)).disabled(app.entries.isEmpty)
                    .help("Show or hide the whole collection without changing the selected preview")
                Button { app.settings.paused.toggle() } label: {
                    Label(app.settings.paused ? "Resume minis" : "Pause minis", systemImage: app.settings.paused ? "play" : "pause")
                        .font(.system(size: 11, weight: .medium)).lineLimit(1).minimumScaleFactor(0.85).frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(PawletActionStyle(compact: true)).help("Pause or resume desktop animations")
            }.padding(10).background(PawletTheme.surface.opacity(0.7), in: PawletTheme.roundedShape(12))
        }.padding(10).frame(width: 156).frame(maxHeight: .infinity).background(PawletTheme.sidebar)
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
                .contentShape(PawletTheme.roundedShape(10))
        }.buttonStyle(PawletPlainStyle(selected: app.section == id, radius: 10)).accessibilityAddTraits(app.section == id ? .isSelected : []).accessibilityRemoveTraits(app.section == id ? [] : .isSelected)
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
                Button { app.revealLibrary() } label: { Label("Minis folder", systemImage: "folder") }.buttonStyle(PawletActionStyle())
                    .accessibilityLabel("Open minis folder").help("Open the library folder containing all your minis")
                Button { app.importPicker() } label: { Label("Import", systemImage: "square.and.arrow.down") }.buttonStyle(PawletActionStyle())
                Button { app.isCreating = true } label: { Label("Create", systemImage: "plus") }.buttonStyle(PawletActionStyle(prominent: true))
            }
            if app.entries.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "pawprint").font(.system(size: 44)).foregroundStyle(petAccent)
                    Text("Who's keeping you company?").font(.title2.weight(.semibold))
                    Text("Import a mini, or bring a new character to life.").foregroundStyle(PawletTheme.secondary)
                    Button("Import your first mini") { app.importPicker() }.buttonStyle(PawletActionStyle(prominent: true))
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass").foregroundStyle(PawletTheme.secondary).accessibilityHidden(true)
                            TextField("Find a mini", text: $search).textFieldStyle(.plain).font(.callout).accessibilityLabel("Search minis").focused($searchFocused)
                            if !search.isEmpty {
                                Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(PawletPlainStyle()).accessibilityLabel("Clear search")
                            }
                        }.padding(10).modifier(PawletFieldBorder(focused: searchFocused))
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
                Button("Mini formats & sharing") { formatHelp = true }.font(.caption).padding(6).buttonStyle(PawletPlainStyle())
                Spacer()
            }
        }.padding(24)
    }

    private func petCard(_ pet: LibraryPet) -> some View {
        let selected = app.selectedID == pet.id
        let visible = app.isVisible(pet.id)
        return VStack(alignment: .leading, spacing: 8) {
            Button { app.selectedID = pet.id } label: {
                VStack(alignment: .leading, spacing: 12) {
                    Image(nsImage: app.image(for: pet.id)).resizable().interpolation(.high).scaledToFit()
                        .frame(height: 132).frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(PawletTheme.stage, in: PawletTheme.roundedShape(10))
                        .clipShape(PawletTheme.roundedShape(10))
                    Text(pet.manifest.name).font(.system(size: 14, weight: .semibold, design: .rounded))
                        .lineLimit(1).padding(.horizontal, 4).padding(.bottom, 2)
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(PawletPlainStyle(radius: 10)).accessibilityLabel("Select \(pet.manifest.name)")
                .accessibilityAddTraits(selected ? .isSelected : []).accessibilityRemoveTraits(selected ? [] : .isSelected)
            Button { app.togglePetVisibility(pet.id) } label: {
                Label(visible ? "Hide mini" : "Show mini", systemImage: visible ? "eye.slash" : "eye")
            }.buttonStyle(PawletActionStyle(compact: true, fillsWidth: true))
                .accessibilityLabel("\(visible ? "Hide" : "Show") \(pet.manifest.name) on desktop")
                .help("Show or hide \(pet.manifest.name) with one click; keep the current preview selected.")
        }.padding(8).background(PawletTheme.surface, in: PawletTheme.roundedShape(18))
            .overlay(PawletTheme.roundedShape(18).strokeBorder(selected ? petAccent : PawletTheme.border, lineWidth: selected ? 1.5 : 1).allowsHitTesting(false))
    }

    private var settingsPage: some View { SettingsView(app: app) }

    private var aboutPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(nsImage: app.pawImage).resizable().renderingMode(.template).scaledToFit().frame(width: 44, height: 44).foregroundStyle(petAccent).accessibilityHidden(true)
            Text("Pawlet").font(.system(size: 32, weight: .bold, design: .rounded))
            Text("Your characters. Your desktop.").font(.title3)
            Text("An offline Mac app for collecting and enjoying animated companions. Add a mini pack, import a compatible sprite sheet, or make something new with Codex.").foregroundStyle(.secondary)
            Divider()
            Text("The app works without Codex. Codex is only used when you choose to create new artwork.")
            Text("No accounts, telemetry or network listener. Imported minis are image and metadata files; they don't run code.").font(.callout).foregroundStyle(.secondary)
            Button("Learn about mini packs") { formatHelp = true }.buttonStyle(PawletActionStyle())
            Text("Version 0.6.2 · macOS 13+").font(.caption).foregroundStyle(.secondary)
            Spacer()
        }.padding(36).frame(maxWidth: .infinity, alignment: .leading)
    }

    private var formatPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("A mini in one file").font(.title.weight(.bold))
            Text("A .petpack is a ZIP with two files at its root:")
            Text("manifest.json\nspritesheet.png").font(.system(.body, design: .monospaced)).padding(16)
                .frame(maxWidth: .infinity, alignment: .leading).background(.quaternary, in: PawletTheme.roundedShape(10))
            Text("The JSON names the mini and its sprite format. The transparent PNG holds every pose in a fixed grid. Preview images are optional.")
            Text("Import also accepts a Codex mini folder or ZIP with pet.json and its sprite sheet. Use Share → Export for Codex to save the same artwork in that format, or use the folder button at the top of the library to browse all your minis.").font(.callout)
            Text("v2: 1536 × 2288, 192 × 208 cells, 9 animations + 16 gaze poses.\nv1: 1536 × 1872, 9 animations without gaze tracking.").font(.callout).foregroundStyle(.secondary)
            Text("A regular photo is a creation reference, not an animated mini. Use Create to turn it into one.").font(.callout)
            HStack { Spacer(); Button("Got it") { formatHelp = false }.buttonStyle(PawletActionStyle(prominent: true)).keyboardShortcut(.defaultAction) }
        }.padding(28).frame(width: 470)
    }
}
