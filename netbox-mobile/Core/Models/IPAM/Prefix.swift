import Foundation

struct PagedResponse<T: Decodable & Sendable>: Decodable, Sendable {
    let count: Int
    let next: URL?
    let previous: URL?
    let results: [T]
}

struct StatusValue: Decodable, Hashable, Sendable {
    let value: String
    let label: String
}

struct AddressFamily: Decodable, Hashable, Sendable {
    let value: Int
    let label: String
}

struct Prefix: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let prefix: String
    let vrf: NestedVRF?
    let status: StatusValue
    let description: String
    let isPool: Bool
    let family: AddressFamily
    let utilization: Double?
}
