import SwiftUI

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    var message: String? = nil
    var actionTitle: String? = nil
    var actionSystemImage: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 68, height: 68)
                .background(
                    Circle()
                        .fill(.secondary.opacity(0.12))
                )
                .symbolEffect(.pulse, isActive: true)

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)

            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    if let actionSystemImage {
                        Label(actionTitle, systemImage: actionSystemImage)
                    } else {
                        Text(actionTitle)
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

struct CachedDataBanner: View {
    let date: Date?

    var body: some View {
        Label(message, systemImage: "externaldrive.badge.clock")
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.secondary.opacity(0.10))
    }

    private var message: String {
        guard let date else {
            return "Showing cached data"
        }
        return "Showing cached data from \(date.formatted(date: .abbreviated, time: .shortened))"
    }
}
