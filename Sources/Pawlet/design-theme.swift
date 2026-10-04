import SwiftUI
import AppKit

enum PawletTheme {
    static let canvas = color(light: 0xF6F5F2, dark: 0x1C1E1D)
    static let surface = color(light: 0xFFFFFF, dark: 0x292C2A)
    static let stage = color(light: 0xEEEEE6, dark: 0x30362F)
    static let secondary = color(light: 0x626762, dark: 0xBAC2BA)
    static let border = color(light: 0xDEDFD8, dark: 0x444A44)
    static let accent = color(light: 0x345D4E, dark: 0xA8D4BD)
    static let button = Color(red: 0.20, green: 0.36, blue: 0.30)
    private static func color(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let value = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(red: CGFloat((value >> 16) & 255) / 255, green: CGFloat((value >> 8) & 255) / 255, blue: CGFloat(value & 255) / 255, alpha: 1)
        })
    }
}

struct PawletActionStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var prominent = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 13).frame(height: 34)
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .background(prominent ? PawletTheme.button : PawletTheme.surface, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(prominent ? PawletTheme.button : PawletTheme.border))
            .opacity(!isEnabled ? 0.45 : configuration.isPressed ? 0.72 : 1)
    }
}
