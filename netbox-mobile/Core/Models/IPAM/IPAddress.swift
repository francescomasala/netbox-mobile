import Foundation

struct IPAddress: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let address: String
    let vrf: NestedVRF?
    let status: StatusValue
    let dnsName: String
    let description: String
    let assignedObject: AssignedObject?
}

struct AssignedObject: Decodable, Hashable, Sendable {
    let display: String
}
