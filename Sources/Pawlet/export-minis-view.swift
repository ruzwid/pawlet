import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ExportMinisView: View {
    @ObservedObject var app: AppDelegate
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var selectedIDs = Set<String>()
    @State private var isSaving = false
    @State private var error: String?
    @FocusState private var searchFocused: Bool

    private var filteredMinis: [LibraryPet] {
        app.entries.filter { search.isEmpty || $0.manifest.name.localizedStandardContains(search) || $0.manifest.description.localizedStandardContains(search) }
    }
    private var selectedMinis: [LibraryPet] { app.entries.filter { selectedIDs.contains($0.id) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Export minis").font(.system(size: 25, weight: .bold, design: .rounded))
                Text("Choose minis to share in one ZIP.").font(.callout).foregroundStyle(PawletTheme.secondary)
            }
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(PawletTheme.secondary).accessibilityHidden(true)
                TextField("Find a mini", text: $search).textFieldStyle(.plain).focused($searchFocused).accessibilityLabel("Search minis to export")
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(PawletPlainStyle()).accessibilityLabel("Clear export search")
                }
            }.padding(10).modifier(PawletFieldBorder(focused: searchFocused))
            HStack {
                Text("\(filteredMinis.count) \(filteredMinis.count == 1 ? "mini" : "minis")").font(.caption).foregroundStyle(PawletTheme.secondary)
                Spacer()
                Button(search.isEmpty ? "Select all" : "Select results") { selectedIDs.formUnion(filteredMinis.map { $0.id }) }
                    .buttonStyle(PawletActionStyle(compact: true)).disabled(isSaving || filteredMinis.isEmpty || filteredMinis.allSatisfy { selectedIDs.contains($0.id) })
                Button("Deselect all") { selectedIDs.removeAll() }.buttonStyle(PawletActionStyle(compact: true)).disabled(isSaving || selectedIDs.isEmpty)
            }
            ScrollView {
                LazyVStack(spacing: 6) {
                    if filteredMinis.isEmpty {
                        Text("No minis found.").font(.callout).foregroundStyle(PawletTheme.secondary)
                            .frame(maxWidth: .infinity).padding(.vertical, 70)
                    } else {
                        ForEach(filteredMinis) { mini in exportRow(mini) }
                    }
                }.padding(6)
            }.frame(height: 290).background(PawletTheme.surface, in: PawletTheme.roundedShape(14))
                .overlay(PawletTheme.roundedShape(14).strokeBorder(PawletTheme.border))
            Text("One folder per mini, ready for Pawlet or Codex. Artwork stays unchanged.")
                .font(.caption).foregroundStyle(PawletTheme.secondary)
            if let error = error { Text(error).font(.callout).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
            Divider()
            HStack(spacing: 10) {
                if isSaving {
                    ProgressView().controlSize(.small)
                    Text("Preparing ZIP…").font(.callout).foregroundStyle(PawletTheme.secondary)
                } else {
                    Text("\(selectedMinis.count) selected").font(.callout).monospacedDigit().foregroundStyle(PawletTheme.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(PawletActionStyle()).keyboardShortcut(.cancelAction).disabled(isSaving)
                Button { saveZIP() } label: { Label("Export ZIP…", systemImage: "square.and.arrow.up") }
                    .buttonStyle(PawletActionStyle(prominent: true)).keyboardShortcut(.defaultAction).disabled(selectedMinis.isEmpty || isSaving)
            }
        }.padding(26).frame(width: 520).background(PawletTheme.canvas).foregroundStyle(PawletTheme.ink)
            .interactiveDismissDisabled(isSaving)
            .onAppear { searchFocused = true }
    }

    private func exportRow(_ mini: LibraryPet) -> some View {
        let isSelected = selectedIDs.contains(mini.id)
        return Button {
            if isSelected { selectedIDs.remove(mini.id) } else { selectedIDs.insert(mini.id) }
        } label: {
            HStack(spacing: 12) {
                Image(nsImage: app.image(for: mini.id)).resizable().scaledToFit().padding(5)
                    .frame(width: 52, height: 56).background(PawletTheme.stage, in: PawletTheme.roundedShape(10)).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(mini.manifest.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    Text(mini.manifest.description).font(.caption).foregroundStyle(PawletTheme.secondary).lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19)).foregroundStyle(isSelected ? PawletTheme.accent : PawletTheme.secondary).accessibilityHidden(true)
            }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
        }.buttonStyle(PawletPlainStyle(selected: isSelected, radius: 10)).disabled(isSaving)
            .accessibilityLabel("Include \(mini.manifest.name)").accessibilityValue(isSelected ? "Selected" : "Not selected")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func saveZIP() {
        let minis = selectedMinis
        let panel = NSSavePanel()
        panel.title = "Export \(minis.count) \(minis.count == 1 ? "mini" : "minis")"
        panel.allowedContentTypes = [.zip]
        panel.nameFieldStringValue = "Pawlet-Minis.zip"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        isSaving = true; error = nil
        Task { @MainActor in
            do {
                try await MiniCollectionExport.writeInBackground(minis, to: destination)
                isSaving = false; dismiss()
                NSWorkspace.shared.activateFileViewerSelecting([destination])
            } catch { self.error = error.localizedDescription; isSaving = false }
        }
    }
}
