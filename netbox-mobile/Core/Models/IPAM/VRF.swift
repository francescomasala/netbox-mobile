import Foundation

struct NestedVRF: Codable, Hashable, Sendable {
    let id: Int
    let name: String
    let rd: String?
}
