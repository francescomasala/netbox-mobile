import Foundation

struct Manufacturer: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let slug: String
}
