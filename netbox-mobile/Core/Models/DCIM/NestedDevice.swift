import Foundation

struct NestedDevice: Codable, Hashable, Sendable {
    let id: Int
    let name: String?
    let display: String
}
