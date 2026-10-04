import AppKit
import SwiftUI

enum PreviewClip: String, CaseIterable, Identifiable {
    case idle, runningRight = "running-right", runningLeft = "running-left"
    case waving, jumping, failed, waiting, working = "running", review, look
    var id: String { rawValue }
    var state: PetState? { PetState(rawValue: rawValue) }
    var title: String { state?.title ?? "Look around" }
    var symbol: String { state?.symbol ?? "eye" }
    var count: Int { state?.count ?? 16 }
    var secondsPerFrame: Double { state?.secondsPerFrame ?? 0.18 }
    var detail: String { state?.detail ?? "Sixteen gaze poses, clockwise from looking up." }
    func frame(at index: Int) -> SpriteFrame {
        let column = min(count - 1, max(0, index))
        return state.map { SpriteFrame(row: $0.row, column: column) }
            ?? SpriteFrame(row: 9 + column / 8, column: column % 8)
    }
    func frameIndex(elapsed: Double, speed: Double) -> Int {
        let elapsedSeconds = elapsed.isFinite ? max(0, elapsed) : 0
        let multiplier = speed.isFinite ? min(MotionConstants.MAX_SPEED_MULTIPLIER, max(MotionConstants.MIN_SPEED_MULTIPLIER, speed)) : 1
        let duration = Double(count) * secondsPerFrame
        return min(count - 1, Int((elapsedSeconds * multiplier).truncatingRemainder(dividingBy: duration) / secondsPerFrame))
    }
    static func available(hasLookDirections: Bool) -> [PreviewClip] {
        allCases.filter { $0 != .look || hasLookDirections }
    }
}

final class AnimationPreviewModel: ObservableObject {
    @Published private(set) var clip = PreviewClip.idle
    @Published private(set) var frameIndex = 0
    @Published private(set) var image: NSImage?
    @Published private(set) var isPlaying = false
    @Published private(set) var error: String?
    @Published private(set) var reducedMotion = false
    @Published private(set) var speed = 1.0
    private(set) var atlas: SpriteAtlas?
    weak var window: NSWindow?
    private var timer: Timer?
    private var started = 0.0
    var availableClips: [PreviewClip] { PreviewClip.available(hasLookDirections: atlas?.hasLookDirections == true) }

    func load(_ pet: LibraryPet) {
        stop()
        atlas = nil; error = nil; clip = .idle; frameIndex = 0; image = nil
        do { atlas = try SpriteAtlas(manifest: pet.manifest, directory: pet.directory); display(0) }
        catch { self.error = error.localizedDescription }
    }
    func select(_ selected: PreviewClip) {
        guard atlas != nil, availableClips.contains(selected) else { return }
        stop(); clip = selected; display(0)
        if !reducedMotion { play() }
    }
    func setSpeed(_ value: Double) {
        let playing = isPlaying
        stop(); speed = value; if playing { play() }
    }
    func setReducedMotion(_ value: Bool) {
        reducedMotion = value
        if value { stop() }
    }
    func play() {
        guard atlas != nil, !reducedMotion else { return }
        stop(); isPlaying = true
        started = ProcessInfo.processInfo.systemUptime - Double(frameIndex) * clip.secondsPerFrame / speed
        let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            guard self.window?.isVisible == true, self.window?.isMiniaturized == false, self.window?.occlusionState.contains(.visible) == true, !NSApp.isHidden else { self.stop(); return }
            self.display(self.clip.frameIndex(elapsed: ProcessInfo.processInfo.systemUptime - self.started, speed: self.speed))
        }
        timer.tolerance = 0.01; RunLoop.main.add(timer, forMode: .common); self.timer = timer
    }
    func stop() { timer?.invalidate(); timer = nil; isPlaying = false }
    func step(_ delta: Int) {
        stop(); display((frameIndex + delta % clip.count + clip.count) % clip.count)
    }
    private func display(_ index: Int) {
        guard let atlas = atlas else { return }
        if frameIndex != index || image == nil { frameIndex = index; image = atlas.frame(clip.frame(at: index)) }
    }
    deinit { timer?.invalidate() }
}

struct AnimationPreviewView: View {
    @ObservedObject var model: AnimationPreviewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 0) {
                HStack {
                    Menu {
                        ForEach(model.availableClips) { clip in Button(clip.title) { model.select(clip) } }
                    } label: { Label(model.clip.title, systemImage: model.clip.symbol).font(.system(size: 12, weight: .semibold)) }
                        .menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Preview animation")
                    Spacer()
                    Text(model.isPlaying ? "PLAYING" : "PREVIEW").font(.system(size: 9, weight: .semibold)).tracking(1.2).foregroundStyle(PawletTheme.secondary)
                }.padding(16)
                ZStack {
                    Ellipse().fill(petAccent.opacity(0.10)).frame(width: 110, height: 12).offset(y: 74)
                    if let image = model.image {
                        Image(nsImage: image).resizable().interpolation(.high).scaledToFit().frame(width: 170, height: 184)
                            .accessibilityLabel("\(model.clip.title), frame \(model.frameIndex + 1) of \(model.clip.count)")
                    } else {
                        Image(systemName: "pawprint").font(.system(size: 52)).foregroundStyle(petAccent.opacity(0.35)).accessibilityHidden(true)
                    }
                }.frame(maxWidth: .infinity).frame(height: 185)
                HStack(spacing: 10) {
                    Button { if model.isPlaying { model.stop() } else { model.play() } } label: {
                        Label(model.isPlaying ? "Pause" : "Play", systemImage: model.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 12, weight: .semibold)).frame(width: 66)
                    }.buttonStyle(.bordered).disabled(model.reducedMotion || model.atlas == nil)
                    Spacer()
                    Button { model.step(-1) } label: { Image(systemName: "backward.end.fill") }
                        .accessibilityLabel("Previous frame").help("Pause and show the previous frame")
                    Text("\(model.frameIndex + 1) / \(model.clip.count)").font(.system(size: 11, design: .monospaced)).foregroundStyle(PawletTheme.secondary).frame(width: 48)
                    Button { model.step(1) } label: { Image(systemName: "forward.end.fill") }
                        .accessibilityLabel("Next frame").help("Pause and show the next frame")
                    Menu {
                        ForEach([0.5, 1.0, 1.5], id: \.self) { speed in
                            Button("\(speed.formatted())× speed") { model.setSpeed(speed) }
                        }
                    } label: { Text("\(model.speed.formatted())×").font(.caption.monospacedDigit()) }.frame(width: 48)
                }.buttonStyle(.borderless).padding(16)
            }
            .background(PawletTheme.stage, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(PawletTheme.border))
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("ANIMATIONS").font(.system(size: 10, weight: .semibold)).tracking(1.3).foregroundStyle(PawletTheme.secondary)
                    Spacer()
                    if model.availableClips.contains(.look) {
                        Button { model.select(.look) } label: { Label("Gaze", systemImage: "eye").font(.caption) }
                            .buttonStyle(.borderless).accessibilityLabel("Preview sixteen gaze poses")
                            .accessibilityAddTraits(model.clip == .look ? .isSelected : []).accessibilityRemoveTraits(model.clip == .look ? [] : .isSelected)
                    }
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(model.availableClips.filter { $0 != .look }) { clip in
                        Button { model.select(clip) } label: {
                            Label(clip == .look ? "Gaze" : clip.title, systemImage: clip.symbol).lineLimit(1).minimumScaleFactor(0.85).font(.system(size: 11, weight: model.clip == clip ? .semibold : .medium))
                                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 10).frame(height: 33)
                                .foregroundStyle(model.clip == clip ? petAccent : Color.primary)
                                .background(model.clip == clip ? petAccent.opacity(0.12) : PawletTheme.surface, in: RoundedRectangle(cornerRadius: 9))
                                .overlay(RoundedRectangle(cornerRadius: 9).stroke(model.clip == clip ? petAccent.opacity(0.5) : PawletTheme.border))
                        }.buttonStyle(.plain).accessibilityAddTraits(model.clip == clip ? .isSelected : []).accessibilityRemoveTraits(model.clip == clip ? [] : .isSelected).help(clip.detail)
                    }
                }.disabled(model.atlas == nil)
                Text(model.error ?? (model.reducedMotion ? "Reduce Motion is on. Use the frame arrows to explore each pose." : model.clip.detail))
                    .font(.caption).foregroundStyle(PawletTheme.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear { model.setReducedMotion(reduceMotion) }
        .onChange(of: reduceMotion) { model.setReducedMotion($0) }
        .onDisappear { model.stop() }
    }
}
