import SwiftUI

struct WindowOpacityControl: View {
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Window opacity")
                Spacer()
                Text(value, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit()
            }

            Slider(value: $value, in: WindowOpacity.range, step: 0.01) {
                Text("Window opacity")
            }
            .labelsHidden()
            .accessibilityIdentifier("window-opacity-slider")
            .accessibilityValue(Text(value, format: .percent.precision(.fractionLength(0))))

            HStack {
                Text("50%")
                Spacer()
                Text("100% (Opaque)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
