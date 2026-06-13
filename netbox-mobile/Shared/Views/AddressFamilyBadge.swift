import SwiftUI

struct AddressFamilyBadge: View {
    let family: AddressFamily

    var body: some View {
        let color = family.value == 6 ? Color.purple : Color.blue

        Text("IPv\(family.value)")
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .foregroundStyle(color)
            .background(
                Capsule()
                    .fill(color.opacity(0.12))
            )
            .overlay {
                Capsule()
                    .stroke(color.opacity(0.22), lineWidth: 1)
            }
            .fixedSize(horizontal: true, vertical: false)
    }
}
