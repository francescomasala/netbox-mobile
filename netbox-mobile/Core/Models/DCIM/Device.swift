import Foundation

struct NestedIPAddress: Decodable, Hashable, Sendable {
    let id: Int
    let address: String
    let display: String
}

struct Device: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String?
    let display: String
    let deviceType: DeviceType
    let site: NestedSite?
    let rack: NestedRack?
    let position: Double?
    let status: StatusValue
    let primaryIp: NestedIPAddress?
    let primaryIp4: NestedIPAddress?
    let primaryIp6: NestedIPAddress?
    let assetTag: String?
    let serial: String
    let description: String
    let comments: String

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        display = try c.decodeIfPresent(String.self, forKey: .display)
            ?? c.decodeIfPresent(String.self, forKey: .displayName)
            ?? name
            ?? "Device #\(id)"
        deviceType = try c.decode(DeviceType.self, forKey: .deviceType)
        site = try c.decodeIfPresent(NestedSite.self, forKey: .site)
        rack = try c.decodeIfPresent(NestedRack.self, forKey: .rack)
        position = try c.decodeIfPresent(Double.self, forKey: .position)
        status = try c.decode(StatusValue.self, forKey: .status)
        primaryIp = try c.decodeIfPresent(NestedIPAddress.self, forKey: .primaryIp)
        primaryIp4 = try c.decodeIfPresent(NestedIPAddress.self, forKey: .primaryIp4)
        primaryIp6 = try c.decodeIfPresent(NestedIPAddress.self, forKey: .primaryIp6)
        assetTag = try c.decodeIfPresent(String.self, forKey: .assetTag)
        serial = try c.decodeIfPresent(String.self, forKey: .serial) ?? ""
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        comments = try c.decodeIfPresent(String.self, forKey: .comments) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, display, displayName, deviceType, site, rack, position, status
        case primaryIp, primaryIp4, primaryIp6, assetTag, serial, description, comments
    }
}
