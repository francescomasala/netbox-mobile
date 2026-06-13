import SwiftUI

struct UtilizationMeter: View {
    let value: Double

    var body: some View {
        HStack(spacing: 8) {
            ProgressView(value: clampedValue, total: 100)
                .progressViewStyle(.linear)
                .tint(meterColor)
                .frame(maxWidth: 130)

            Text("\(Int(clampedValue.rounded()))%")
                .font(.caption.monospacedDigit().weight(.medium))
                .foregroundStyle(meterColor)
                .frame(width: 36, alignment: .trailing)
        }
    }

    private var clampedValue: Double {
        min(max(value, 0), 100)
    }

    private var meterColor: Color {
        switch clampedValue {
        case ..<60: .green
        case ..<85: .orange
        default: .red
        }
    }
}
