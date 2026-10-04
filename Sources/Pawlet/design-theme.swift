import SwiftUI
import AppKit

enum PawletTheme {
    static let canvas = color(light: 0xF8F8F2, dark: 0x1E2018)
    static let surface = color(light: 0xFFFFFB, dark: 0x282B20)
    static let stage = color(light: 0xF0F1E6, dark: 0x303426)
    static let secondary = color(light: 0x66685D, dark: 0xBBC0A8)
    static let border = color(light: 0xDDDED4, dark: 0x484E39)
    static let accent = color(light: 0x627000, dark: 0xCCD889)
    static let button = color(light: 0x627000, dark: 0xBBC96A)
    static let buttonInk = color(light: 0xFFFFFB, dark: 0x232715)
    static let ink = color(light: 0x292A25, dark: 0xF0F1E7)
    static let sidebar = color(light: 0xF1F2E9, dark: 0x23261C)
    static let switchOff = color(light: 0xE2E4D8, dark: 0x3A402E)
    static let switchBorder = color(light: 0x7A7D73, dark: 0x89916B)
    static let switchThumbOn = color(light: 0xFFFFFB, dark: 0x1E2018)
    static let switchThumbOff = color(light: 0x73766A, dark: 0xB8BEA4)
    static func roundedShape(_ radius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
    private static func color(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let value = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(red: CGFloat((value >> 16) & 255) / 255, green: CGFloat((value >> 8) & 255) / 255, blue: CGFloat(value & 255) / 255, alpha: 1)
        })
    }
}

struct PawletActionStyle: ButtonStyle {
    var prominent = false
    var compact = false
    var fillsWidth = false
    var selected = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: compact ? 11 : 12, weight: .semibold))
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .padding(.horizontal, compact ? 8 : 13).frame(height: 34)
            .modifier(ControlSurface(background: prominent ? PawletTheme.button : PawletTheme.surface,
                selected: selected, prominent: prominent, isPressed: configuration.isPressed))
    }
}
