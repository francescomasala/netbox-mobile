import Foundation

struct DeviceType: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let manufacturer: Manufacturer
    let model: String
    let slug: String
    let uHeight: Double?
}
