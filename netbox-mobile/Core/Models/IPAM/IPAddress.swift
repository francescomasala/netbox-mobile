import Foundation

struct IPAddress: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let address: String
    let vrf: NestedVRF?
    let status: StatusValue
    let dnsName: String
    let description: String
    let assignedObject: AssignedObject?
}

struct AssignedObject: Codable, Hashable, Sendable {
    let display: String
}
