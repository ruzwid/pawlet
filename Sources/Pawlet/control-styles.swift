import SwiftUI

enum InterfaceMotion {
    static let hoverFeedback = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.10)
}

struct ControlSurface: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false
    var background = Color.clear
    var foreground = PawletTheme.accent
    var radius: CGFloat = 10
    var bordered = true
    var selected = false
    var prominent = false
    var isPressed = false

    private var foregroundColor: Color {
        if prominent { return .white }
        if isHovered && isEnabled { return PawletTheme.accent }
        return foreground
    }
    private var borderColor: Color {
        guard bordered else { return .clear }
        if prominent { return PawletTheme.button }
        if selected || isHovered && isEnabled { return PawletTheme.accent.opacity(0.55) }
        return PawletTheme.border
    }

    func body(content: Content) -> some View {
        content
            .foregroundStyle(foregroundColor)
            .background {
                ZStack {
                    PawletTheme.roundedShape(radius).fill(selected ? PawletTheme.accent.opacity(0.11) : background)
                    PawletTheme.roundedShape(radius).fill(prominent ? Color.white.opacity(0.10) : PawletTheme.accent.opacity(0.09))
                        .opacity(isHovered && isEnabled ? 1 : 0)
                        .animation(reduceMotion ? nil : InterfaceMotion.hoverFeedback, value: isHovered)
                    PawletTheme.roundedShape(radius).fill(prominent ? Color.black.opacity(0.13) : PawletTheme.accent.opacity(0.15))
                        .opacity(isPressed && isEnabled ? 1 : 0)
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

    func makeBody(configuration: Configuration) -> some View {
        configuration.label.modifier(ControlSurface(foreground: selected ? PawletTheme.accent : PawletTheme.ink,
            radius: radius, bordered: false, selected: selected, isPressed: configuration.isPressed))
    }
}

struct PawletFieldBorder: ViewModifier {
    @State private var isHovered = false
    var focused = false

    private var borderColor: Color {
        if focused { return PawletTheme.accent }
        if isHovered { return PawletTheme.accent.opacity(0.55) }
        return PawletTheme.border
    }

    func body(content: Content) -> some View {
        content.background(PawletTheme.surface, in: PawletTheme.roundedShape(10))
            .overlay(PawletTheme.roundedShape(10).strokeBorder(borderColor, lineWidth: focused ? 1.5 : 1).allowsHitTesting(false))
            .onHover { isHovered = $0 }
    }
}
