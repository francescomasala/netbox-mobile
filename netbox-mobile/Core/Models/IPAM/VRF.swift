import Foundation

struct NestedVRF: Decodable, Hashable, Sendable {
    let id: Int
    let name: String
    let rd: String?
}
