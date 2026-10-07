import SwiftUI

struct SettingsView: View {
    @ObservedObject var app: AppDelegate

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                settingsSection("Hello & interactions") {
                    Toggle("React when I hover", isOn: $app.settings.greetOnHover)
                    HStack {
                        Text("Default hover reaction")
                        Spacer()
                        ChoiceMenu(title: "Default hover reaction", selection: $app.settings.hoverReaction,
                            choices: HoverReaction.allCases.map { MenuChoice(value: $0, title: $0.title) })
                            .disabled(!app.settings.greetOnHover)
                    }
                    hint("Each mini can have its own reaction. Hover plays once and ignores the time between animations.")
                    Divider()
                    Toggle("Animate clicks and drags", isOn: $app.settings.animateInteractions)
                }
                settingsSection("Movement & rest") {
                    Toggle("Animate while idle", isOn: $app.settings.animateIdle)
                    Toggle("Follow the cursor", isOn: $app.settings.followCursor)
                    Toggle("Wander occasionally", isOn: $app.settings.wander)
                    Toggle("Loop working, waiting and review animations", isOn: $app.settings.loopActivities)
                    Divider()
                    SettingsSliderRow(title: "Time between animations", value: $app.settings.animationInterval,
                        range: 0...MotionConstants.MAX_INTERVAL_SECONDS, step: 1,
                        displayValue: app.settings.animationInterval == 0 ? "None" : "\(Int(app.settings.animationInterval)) s")
                    hint("Rest after each idle or activity loop. Zero plays continuously; clicks and greetings respond immediately.")
                    Toggle("Pause all animations", isOn: $app.settings.paused)
                    SettingsSliderRow(title: "Animation speed", value: $app.settings.speed,
                        range: 0.5...1.5, displayValue: "\(Int(app.settings.speed * 100))%")
                    hint("Idle movement is off by default. Your Mac's Reduce Motion setting always takes priority.")
                }
                settingsSection("On your desktop") {
                    SettingsSliderRow(title: "Default mini size", value: $app.settings.size,
                        range: MotionConstants.MIN_PET_SCALE...MotionConstants.MAX_PET_SCALE,
                        displayValue: "\(Int((app.settings.size * 100).rounded()))%")
                    hint("Change an individual mini’s size in its preview card. Minis without an override use this default.")
                    SettingsSliderRow(title: "Opacity", value: $app.settings.opacity,
                        range: 0.3...1, displayValue: "\(Int(app.settings.opacity * 100))%")
                    Divider()
                    Toggle("Stay above other windows", isOn: $app.settings.alwaysOnTop)
                    Toggle("Show on all desktop Spaces", isOn: $app.settings.allSpaces)
                    Toggle("Let clicks pass through minis", isOn: $app.settings.clickThrough)
                    Toggle("Remember place per app", isOn: $app.settings.rememberPlacePerApp)
                    hint("Restore follows the topmost fullscreen app on the mini’s monitor, or else the topmost window on that monitor. Dragging or resizing a mini while that app is active saves its place and size; switching back restores with a short fade. Wandering does not change a saved place. Apps without a saved place leave the mini where it is. Apps without a saved size use this mini's usual size. Reduce Motion skips the fade.")
                    Button("Bring minis back to this screen") { app.resetPositions() }.buttonStyle(PawletActionStyle())
                }
                settingsSection("App") {
                    Toggle("Show the Dock icon", isOn: $app.settings.showDockIcon)
                    Toggle("Open at login", isOn: Binding(get: { app.loginEnabled }, set: { app.setLogin($0) }))
                    HStack {
                        Text("Appearance")
                        Spacer()
                        ChoiceMenu(title: "Appearance", selection: $app.settings.appearance, choices: [
                            MenuChoice(value: "system", title: "System"), MenuChoice(value: "light", title: "Light"), MenuChoice(value: "dark", title: "Dark")
                        ])
                    }
                    Divider()
                    HStack(spacing: 10) {
                        Button("Open minis folder") { app.revealLibrary() }.buttonStyle(PawletActionStyle())
                        Button("Restore quiet defaults") { app.settings = AppSettings() }.buttonStyle(PawletActionStyle())
                    }
                }
            }.font(.system(size: 13)).toggleStyle(PawletToggleStyle())
                .frame(maxWidth: 760).frame(maxWidth: .infinity, alignment: .leading).padding(24)
        }.background(PawletTheme.canvas)
    }

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.system(size: 13, weight: .semibold)).padding(.leading, 2)
            VStack(alignment: .leading, spacing: 14, content: content)
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(PawletTheme.surface, in: PawletTheme.roundedShape(14))
                .overlay(PawletTheme.roundedShape(14).stroke(PawletTheme.border))
        }
    }
    private func hint(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(PawletTheme.secondary).fixedSize(horizontal: false, vertical: true)
    }
}

struct PawletToggleStyle: ToggleStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: 16) {
                configuration.label
                Spacer(minLength: 12)
                PawletTheme.roundedShape(12)
                    .fill(configuration.isOn ? PawletTheme.accent : PawletTheme.switchOff).frame(width: 40, height: 24)
                    .overlay(PawletTheme.roundedShape(12).strokeBorder(configuration.isOn ? .clear : PawletTheme.switchBorder))
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle().fill(configuration.isOn ? PawletTheme.switchThumbOn : PawletTheme.switchThumbOff)
                            .frame(width: 18, height: 18).padding(3)
                    }.frame(width: 40, height: 24)
            }.frame(minHeight: 26).contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityRepresentation {
                Toggle(isOn: configuration.$isOn) { configuration.label }.toggleStyle(.switch).disabled(!isEnabled)
            }
    }
}

struct SettingsSliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step = 0.01
    let displayValue: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title).frame(width: 164, alignment: .leading)
            PawletSlider(title: title, value: $value, range: range, step: step)
            Text(displayValue).monospacedDigit().frame(width: 45).accessibilityHidden(true)
        }
    }
}
