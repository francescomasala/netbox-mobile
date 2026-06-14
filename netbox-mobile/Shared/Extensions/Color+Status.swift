import SwiftUI

extension Color {
    static func netBoxStatus(_ status: String) -> Color {
        switch status.lowercased() {
        case "active":
            .green
        case "planned", "provisioning", "dhcp", "slaac":
            .blue
        case "staged":
            .cyan
        case "deprecated", "decommissioning":
            .orange
        case "reserved":
            .purple
        case "failed", "offline", "decommissioned":
            .red
        default:
            .gray
        }
    }
}
