import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct CreatePetView: View {
    @ObservedObject var app: AppDelegate
    @State private var name = ""
    @State private var idea = ""
    @State private var style = "3d-toy"
    @State private var reference: URL?
    @State private var error: String?
    @State private var preparedPrompt = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Make a new companion").font(.system(size: 25, weight: .bold, design: .rounded))
                    Text("Bring an idea or a reference image. Codex handles the artwork.").foregroundStyle(.secondary)
                }; Spacer()
            }
            TextField("Pet name", text: $name).textFieldStyle(.roundedBorder)
            VStack(alignment: .leading, spacing: 6) {
                Text("What should it look like?").font(.callout.weight(.medium))
                TextEditor(text: $idea).font(.body).frame(height: 105).padding(6)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
            }
            HStack {
                Picker("Style", selection: $style) { Text("3D toy").tag("3d-toy"); Text("Plush").tag("plush"); Text("Pixel").tag("pixel"); Text("Clay").tag("clay"); Text("Sticker").tag("sticker") }
                Spacer()
                Button(reference == nil ? "Add reference image…" : "Change image…") { chooseReference() }
            }
            if let reference = reference { Label(reference.lastPathComponent, systemImage: "photo").font(.caption).foregroundStyle(.secondary) }
            Text("Opens a new Codex chat with the skill and prompt ready. Review it and press Send to begin. Image creation needs Codex and the Pets plugin; your existing pets keep running independently.")
                .font(.callout).foregroundStyle(.secondary)
            if let error = error { Text(error).foregroundStyle(.red).font(.callout) }
            HStack {
                Button("Cancel") { app.isCreating = false }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Copy prompt") { prepare(open: false) }.disabled(!valid)
                Button("Open in Codex") { prepare(open: true) }.buttonStyle(.borderedProminent).tint(petButtonAccent).foregroundStyle(.white).disabled(!valid).opacity(valid ? 1 : 0.55)
            }
        }.padding(28).frame(width: 540).background(Color(nsColor: .windowBackgroundColor))
    }
    private var valid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (!idea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || reference != nil) }
    private func chooseReference() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.image]
        if panel.runModal() == .OK { reference = panel.url }
    }
    private func prepare(open: Bool) {
        do {
            let handoff = try CreationHandoff.prepare(name: name, idea: idea, style: style, reference: reference,
                resources: Bundle.main.resourceURL!, workspaces: app.library.root.deletingLastPathComponent().appendingPathComponent("Creation Workspaces"))
            preparedPrompt = handoff.prompt
            if open {
                if NSWorkspace.shared.urlForApplication(toOpen: handoff.url) != nil && NSWorkspace.shared.open(handoff.url) { app.isCreating = false }
                else { copy(handoff.prompt); error = "Codex isn't installed or didn't open. The prompt is copied; paste it in Codex after installing it." }
            } else { copy(handoff.prompt); error = nil; app.isCreating = false }
        } catch { self.error = error.localizedDescription }
    }
    private func copy(_ text: String) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string) }
}

enum CreationHandoff {
    struct Prepared { let prompt: String; let url: URL; let workspace: URL }
    static func prepare(name: String, idea: String, style: String, reference: URL?, resources: URL, workspaces: URL) throws -> Prepared {
        let fm = FileManager.default
        let workspace = workspaces.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let skill = workspace.appendingPathComponent(".agents/skills/create-desktop-pet", isDirectory: true)
        try fm.createDirectory(at: skill.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.copyItem(at: resources.appendingPathComponent("CreationSkill"), to: skill)
        var referenceNote = "No reference image supplied."
        if let reference = reference {
            let target = workspace.appendingPathComponent("reference." + reference.pathExtension.lowercased())
            try fm.copyItem(at: reference, to: target)
            referenceNote = "Use the reference image at \(target.path) to guide identity."
        }
        let output = workspace.appendingPathComponent("exports", isDirectory: true)
        try fm.createDirectory(at: output, withIntermediateDirectories: true)
        let brief: [String: String] = ["name": name, "idea": idea, "style": style, "reference": referenceNote, "outputDirectory": output.path]
        try JSONSerialization.data(withJSONObject: brief, options: [.prettyPrinted, .sortedKeys]).write(to: workspace.appendingPathComponent("request.json"))
        let prompt = """
        [@Pets](plugin://work-pets@openai-curated-remote) Use $create-desktop-pet from \(skill.path)/SKILL.md to create a standalone Desktop Pets companion.
        Read request.json in this workspace. Name: \(name). Style: \(style). Character idea: \(idea)
        \(referenceNote)
        Follow the installed Pets create-pet artwork workflow through final validated local sprite sheet and motion previews. Do not upload to ChatGPT, create a hosted pet, or select a ChatGPT pet.
        Package the final exact atlas using the local create-desktop-pet skill's scripts/package_pet.py. Save the .petpack in \(output.path).
        Show the motion preview and final .petpack path so I can import it in Desktop Pets. Stop if image generation or the required artwork pipeline is unavailable.
        """
        try prompt.write(to: workspace.appendingPathComponent("PROMPT.md"), atomically: true, encoding: .utf8)
        var components = URLComponents(); components.scheme = "codex"; components.host = "new"
        components.queryItems = [URLQueryItem(name: "prompt", value: prompt), URLQueryItem(name: "path", value: workspace.path)]
        // URLSearchParams treats bare + as a space; preserve C++ and similar briefs.
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        guard let url = components.url else { throw PetLibraryError.invalid("Couldn't prepare the Codex link.") }
        return Prepared(prompt: prompt, url: url, workspace: workspace)
    }
}
