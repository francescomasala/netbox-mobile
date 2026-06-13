import SwiftUI

struct StatusBadge: View {
    let status: StatusValue

    var body: some View {
        let color = Color.netBoxStatus(status.value)

        Text(status.label)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(color)
            .background(
                Capsule()
                    .fill(color.opacity(0.14))
            )
            .overlay {
                Capsule()
                    .stroke(color.opacity(0.26), lineWidth: 1)
            }
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityLabel(status.label)
    }
}
