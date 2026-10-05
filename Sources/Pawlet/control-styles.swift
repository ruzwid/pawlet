import SwiftUI

enum InterfaceMotion {
    static let hoverFeedback = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.10)
}

struct ControlSurface: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false
    var background = Color.clear
    var foreground = PawletTheme.ink
    var accented = false
    var radius: CGFloat = 10
    var bordered = true
    var selected = false
    var prominent = false
    var isPressed = false

    private var foregroundColor: Color {
        if prominent { return PawletTheme.buttonInk }
        if accented && (selected || isEnabled && (isHovered || isPressed)) { return PawletTheme.accent }
        return foreground
    }
    private var borderColor: Color {
        guard bordered else { return .clear }
        if prominent { return PawletTheme.button }
        if selected || isEnabled && (isHovered || isPressed) { return accented ? PawletTheme.accent.opacity(0.55) : PawletTheme.ink.opacity(0.35) }
        return PawletTheme.border
    }

    func body(content: Content) -> some View {
        content
            .foregroundStyle(foregroundColor)
            .background {
                ZStack {
                    PawletTheme.roundedShape(radius).fill(background)
                    PawletTheme.roundedShape(radius).fill(prominent ? Color.black.opacity(0.08) : (accented ? PawletTheme.accent : PawletTheme.controlHighlight).opacity(0.11))
                        .opacity(selected || isEnabled && (isHovered || isPressed) ? 1 : 0)
                        .animation(reduceMotion || selected || isPressed ? nil : InterfaceMotion.hoverFeedback, value: isHovered)
                }.allowsHitTesting(false)
            }
            .overlay {
                PawletTheme.roundedShape(radius)
                    .strokeBorder(borderColor)
                    .allowsHitTesting(false)
            }
            .contentShape(PawletTheme.roundedShape(radius))
            .opacity(isEnabled ? 1 : 0.45)
            .onHover { isHovered = $0 && isEnabled }
            .onDisappear { isHovered = false }
    }
}

struct PawletPlainStyle: ButtonStyle {
    var selected = false
    var radius: CGFloat = 8
    var accented = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label.modifier(ControlSurface(accented: accented, radius: radius, bordered: false, selected: selected, isPressed: configuration.isPressed))
    }
}

struct PawletFieldBorder: ViewModifier {
    @State private var isHovered = false
    var focused = false

    private var borderColor: Color {
        if focused { return PawletTheme.accent }
        if isHovered { return PawletTheme.accent }
        return PawletTheme.border
    }

    func body(content: Content) -> some View {
        content.background(PawletTheme.surface, in: PawletTheme.roundedShape(10))
            .overlay(PawletTheme.roundedShape(10).strokeBorder(borderColor, lineWidth: focused || isHovered ? 1.5 : 1).allowsHitTesting(false))
            .onHover { isHovered = $0 }
    }
}
