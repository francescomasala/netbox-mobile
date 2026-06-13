import SwiftUI

extension Color {
    static func netBoxStatus(_ status: String) -> Color {
        switch status.lowercased() {
        case "active":
            .green
        case "planned":
            .blue
        case "staged":
            .cyan
        case "deprecated":
            .orange
        case "reserved":
            .purple
        default:
            .gray
        }
    }
}
