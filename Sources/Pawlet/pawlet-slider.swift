import SwiftUI

struct PawletSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step = 0.01

    var body: some View {
        Slider(value: Binding(get: { value }, set: { updateValue($0) }), in: range) {
            Text(title)
        }.labelsHidden().accessibilityLabel(title)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: updateValue(value + step)
                case .decrement: updateValue(value - step)
                @unknown default: break
                }
            }
    }

    private func updateValue(_ proposedValue: Double) {
        let steppedValue = range.lowerBound + ((proposedValue - range.lowerBound) / step).rounded() * step
        value = min(range.upperBound, max(range.lowerBound, steppedValue))
    }
}
