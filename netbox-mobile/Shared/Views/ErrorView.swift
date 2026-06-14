import SwiftUI

struct ErrorView: View {
    let error: APIError
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 64, height: 64)
                .background(
                    Circle()
                        .fill(.orange.opacity(0.14))
                )
                .symbolEffect(.pulse, isActive: true)

            Text(error.localizedDescription)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .frame(maxWidth: 420)

            Button(action: retryAction) {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
