import Foundation

struct Manufacturer: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let slug: String
}
