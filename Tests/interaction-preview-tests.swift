import AppKit

enum InteractionPreviewTests {
    static func run(sample: LibraryPet) throws {
        for reaction in HoverReaction.allCases {
            try ProjectTests.require(![PetState.runningLeft, .runningRight, .idle].contains(reaction.state), "Hover must stay in place")
            for speed in [0.5, 1.0, 1.5] {
                let engine = AnimationEngine()
                engine.greet(reaction, now: 100, speed: speed)
                let state = reaction.state
                let duration = Double(state.count) * state.secondsPerFrame / speed
                _ = engine.frame(now: 100, loopActivities: true, speed: speed, animationInterval: 60)
                for index in 0..<state.count {
                    let time = 100 + (Double(index) + 0.25) * state.secondsPerFrame / speed
                    try ProjectTests.require(engine.frame(now: time, loopActivities: true, speed: speed, animationInterval: 60) == SpriteFrame(row: state.row, column: index), "Hover skipped a pose")
                }
                engine.greet(reaction, now: 100 + duration / 2, speed: speed)
                try ProjectTests.require(engine.frame(now: 100 + duration / 2, speed: speed).column == 0, "Re-entry must restart any greeting")
                let settled = engine.frame(now: 100 + duration * 1.5 + 0.01, animateIdle: false, speed: speed)
                try ProjectTests.require(settled == SpriteFrame(row: 0, column: 0) && !engine.isGreeting, "Hover must restore quiet idle")
                engine.perform(.jumping, now: 200)
                try ProjectTests.require(!engine.isGreeting, "A manual action must not remain a greeting")
            }
        }
        var settings = AppSettings(); settings.hoverReaction = .hop
        let saved = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        try ProjectTests.require(saved.hoverReaction == .hop, "Hover preference persistence")
        let previous = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"greetOnHover":false}"#.utf8))
        try ProjectTests.require(!previous.greetOnHover && previous.hoverReaction == .wave, "Hover preference migration")
        let unknown = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"hoverReaction":"running-left"}"#.utf8))
        try ProjectTests.require(unknown.hoverReaction == .wave, "Unsupported hover preference fallback")
        for clip in PreviewClip.allCases {
            for index in 0..<clip.count {
                let elapsed = (Double(index) + 0.25) * clip.secondsPerFrame
                try ProjectTests.require(clip.frameIndex(elapsed: elapsed, speed: 1) == index, "Preview clock skipped a frame")
                try ProjectTests.require(clip.frameIndex(elapsed: elapsed / 1.5, speed: 1.5) == index, "Preview speed mapping")
            }
            let duration = Double(clip.count) * clip.secondsPerFrame
            try ProjectTests.require(clip.frameIndex(elapsed: duration + clip.secondsPerFrame * 0.25, speed: 1) == 0, "Preview must loop without rest")
        }
        try ProjectTests.require(PreviewClip.available(hasLookDirections: false).count == 9 && PreviewClip.available(hasLookDirections: true).count == 10, "v1 preview must exclude gaze")
        let model = AnimationPreviewModel(); model.load(sample)
        try ProjectTests.require(model.atlas?.id == sample.id && !model.isPlaying && model.clip == .idle, "Preview must start still")
        model.select(.waving); model.stop(); model.step(-1)
        try ProjectTests.require(model.frameIndex == 3 && !model.isPlaying, "Reverse frame stepping must wrap")
        model.step(1)
        try ProjectTests.require(model.frameIndex == 0, "Forward frame stepping must wrap")
        model.setReducedMotion(true); model.select(.jumping)
        try ProjectTests.require(!model.isPlaying && model.clip == .jumping, "Reduced Motion must keep previews still")
        model.step(1)
        try ProjectTests.require(model.frameIndex == 1, "Reduced Motion must allow deliberate frame inspection")
        model.load(sample)
        try ProjectTests.require(!model.isPlaying && model.frameIndex == 0 && model.clip == .idle, "Changing pets must reset preview playback")
    }
}
