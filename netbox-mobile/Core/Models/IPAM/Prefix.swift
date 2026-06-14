import Foundation

struct Prefix: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let prefix: String
    let vrf: NestedVRF?
    let status: StatusValue
    let description: String
    let isPool: Bool
    let family: AddressFamily
    let utilization: Double?
}
