import Foundation

struct InterfaceType: Decodable, Hashable, Sendable {
    let value: String
    let label: String
}

struct Interface: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let device: NestedDevice
    let name: String
    let interfaceType: InterfaceType
    let enabled: Bool
    let mtu: Int?
    let macAddress: String?
    let description: String
    let mode: StatusValue?
    let countIpaddresses: Int

    // Explicit CodingKeys needed only to map the `type` JSON key to `interfaceType`
    // (avoiding the Swift `type` keyword). convertFromSnakeCase still applies
    // to the remaining case names since their raw values are camelCase.
    enum CodingKeys: String, CodingKey {
        case id, device, name, enabled, mtu, description, mode
        case interfaceType = "type"
        case macAddress, countIpaddresses
    }
}
