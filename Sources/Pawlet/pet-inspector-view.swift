import SwiftUI

struct PetInspectorView: View {
    @ObservedObject var app: AppDelegate
    @ObservedObject var preview: AnimationPreviewModel
    let pet: LibraryPet
    let rename: () -> Void
    let remove: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(pet.manifest.name).font(.system(size: 27, weight: .bold, design: .rounded))
                        Text(pet.manifest.spriteVersion == 2 ? "9 animations · 16 gaze poses" : "9 animations")
                            .font(.caption).foregroundStyle(PawletTheme.secondary)
                    }
                    Spacer()
                    Menu {
                        Button("Rename…", action: rename)
                        Button("Show this pet's files") { app.revealSelected() }
                        Divider()
                        Button("Move to Trash…", role: .destructive, action: remove)
                    } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 25).accessibilityLabel("Options for \(pet.manifest.name)")
                }
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("On desktop", isOn: Binding(get: { app.isVisible(pet.id) }, set: { app.setPetVisible(pet.id, show: $0) }))
                        .toggleStyle(.switch).font(.system(size: 12, weight: .medium))
                    Picker("On hover", selection: Binding(get: { app.hoverOverride(for: pet.id)?.rawValue ?? "default" }, set: { app.setHoverOverride(HoverReaction(rawValue: $0), for: pet.id) })) {
                        Text("Default (\(app.settings.hoverReaction.title))").tag("default")
                        ForEach(HoverReaction.allCases, id: \.rawValue) { reaction in Text(reaction.title).tag(reaction.rawValue) }
                    }.font(.callout).disabled(!app.settings.greetOnHover)
                        .help("Choose this pet's greeting, or follow the default in Settings. Each entry plays once without a cooldown.")
                    if !app.settings.greetOnHover { Text("Hover reactions are off in Settings.").font(.caption).foregroundStyle(PawletTheme.secondary) }
                }
                AnimationPreviewView(model: preview)
                Text(pet.manifest.description).font(.callout).foregroundStyle(PawletTheme.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Button { app.perform(PetState(rawValue: preview.clip.rawValue) ?? .idle, id: pet.id) } label: {
                        Label("Play on desktop", systemImage: "desktopcomputer")
                    }.buttonStyle(PawletActionStyle()).disabled(preview.clip == .look || preview.atlas == nil || app.settings.paused)
                        .help("Play the selected animation on your desktop pet. Preview playback stays separate.")
                    Spacer(minLength: 0)
                    Menu {
                        Button("Export pet pack…") { app.exportSelected() }
                        Button("Export ZIP…") { app.exportSelected(asZIP: true) }
                        Button("Export for Codex…") { app.exportSelectedForCodex() }
                    } label: { Label("Share", systemImage: "square.and.arrow.up") }.menuStyle(.borderlessButton).fixedSize()
                }
            }.padding(20)
        }
        .background(PawletTheme.surface.opacity(0.55), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(PawletTheme.border))
        .onAppear { preview.window = app.controls; preview.load(pet) }
        .onChange(of: pet.id) { _ in preview.load(pet) }
        .onDisappear { preview.stop() }
    }
}
