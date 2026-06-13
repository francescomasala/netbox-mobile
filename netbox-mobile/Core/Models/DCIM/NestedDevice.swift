import Foundation

struct NestedDevice: Decodable, Hashable, Sendable {
    let id: Int
    let name: String?
    let display: String
}
