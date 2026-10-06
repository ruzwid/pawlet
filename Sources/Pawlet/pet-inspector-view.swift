import SwiftUI

struct PetInspectorView: View {
    @ObservedObject var app: AppDelegate
    @ObservedObject var preview: AnimationPreviewModel
    let pet: LibraryPet
    let rename: () -> Void
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(pet.manifest.name).font(.system(size: 25, weight: .bold, design: .rounded)).lineLimit(2)
                    Text(pet.manifest.spriteVersion == 2 ? "9 animations · 16 gaze poses" : "9 animations")
                        .font(.caption).foregroundStyle(PawletTheme.secondary)
                }
                Spacer(minLength: 8)
                NativeMenuButton(title: "Options for \(pet.manifest.name)", entries: [
                    .action("Rename…", perform: rename),
                    .action("Show this mini's files") { app.revealSelected() },
                    .separator,
                    .action("Move to Trash…", perform: remove)
                ]) {
                    Image(systemName: "ellipsis").font(.system(size: 14, weight: .semibold))
                        .frame(width: 32, height: 32)
                }.buttonStyle(PawletPlainStyle())

            }
            HStack(spacing: 12) {
                Text("On hover").font(.system(size: 12, weight: .medium))
                Spacer(minLength: 4)
                ChoiceMenu(title: "On hover", selection: Binding(get: { app.hoverOverride(for: pet.id)?.rawValue ?? "default" }, set: { app.setHoverOverride(HoverReaction(rawValue: $0), for: pet.id) }),
                    choices: [MenuChoice(value: "default", title: "Default (\(app.settings.hoverReaction.title))")]
                        + HoverReaction.allCases.map { MenuChoice(value: $0.rawValue, title: $0.title) })
                    .disabled(!app.settings.greetOnHover)
                    .help("Choose this mini's greeting, or follow the default in Settings. Each entry plays once without a cooldown.")
            }.padding(.vertical, 2)
            if !app.settings.greetOnHover { Text("Hover reactions are off in Settings.").font(.caption).foregroundStyle(PawletTheme.secondary) }
            HStack(spacing: 12) {
                Text("Size").font(.system(size: 12, weight: .medium))
                PawletSlider(title: "Size for \(pet.manifest.name)",
                    value: Binding(get: { app.miniSize(for: pet.id) }, set: { app.setSizeOverride($0, for: pet.id) }),
                    range: MotionConstants.MIN_PET_SCALE...MotionConstants.MAX_PET_SCALE)
                    .help("Resize this mini on your desktop. Other minis keep their size.")
                Text("\(Int((app.miniSize(for: pet.id) * 100).rounded()))%")
                    .font(.system(size: 12)).monospacedDigit().frame(width: 42, alignment: .trailing)
                Button { app.setSizeOverride(nil, for: pet.id) } label: {
                    Image(systemName: "arrow.counterclockwise").frame(width: 28, height: 28)
                }.buttonStyle(PawletPlainStyle()).disabled(!AppPlacement.hasSizeOverride(defaults: app.defaults, petID: pet.id, rememberPlacePerApp: app.settings.rememberPlacePerApp, appBundleID: app.placementAppBundleID(), selfBundleID: Bundle.main.bundleIdentifier))
                    .accessibilityLabel("Use default size for \(pet.manifest.name)")
                    .help("Use the default size from Settings (\(Int((app.settings.size * 100).rounded()))%)")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    AnimationPreviewView(model: preview)
                    Text(pet.manifest.description).font(.caption).foregroundStyle(PawletTheme.secondary).fixedSize(horizontal: false, vertical: true)
                }.padding(.bottom, 2)
            }
            Divider()
            HStack(spacing: 10) {
                Button { app.perform(PetState(rawValue: preview.clip.rawValue) ?? .idle, id: pet.id) } label: {
                    Label("Play on desktop", systemImage: "desktopcomputer")
                }.buttonStyle(PawletActionStyle()).disabled(preview.clip == .look || preview.atlas == nil || app.settings.paused)
                    .help("Play the selected animation on your desktop mini. Preview playback stays separate.")
                Spacer(minLength: 0)
                NativeMenuButton(title: "Share", entries: [
                    .action("Export mini pack…") { app.exportSelected() },
                    .action("Export ZIP…") { app.exportSelected(asZIP: true) },
                    .action("Export for Codex…") { app.exportSelectedForCodex() }
                ]) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }.buttonStyle(PawletActionStyle())
            }
        }.padding(16)
        .background(PawletTheme.surface.opacity(0.55), in: PawletTheme.roundedShape(18))
        .overlay(PawletTheme.roundedShape(18).stroke(PawletTheme.border))
        .onAppear { preview.window = app.controls }
        .onDisappear { preview.stop() }
    }
}
