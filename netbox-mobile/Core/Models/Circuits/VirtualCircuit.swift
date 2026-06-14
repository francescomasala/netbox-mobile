import Foundation

struct VirtualCircuitType: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let slug: String
    let description: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .display)
            ?? "Type #\(id)"
        slug = try container.decodeIfPresent(String.self, forKey: .slug) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(slug, forKey: .slug)
        try container.encode(description, forKey: .description)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, slug, display, description
    }
}

struct NestedVirtualCircuit: Codable, Hashable, Sendable {
    let id: Int
    let cid: String
    let display: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        cid = try container.decodeIfPresent(String.self, forKey: .cid) ?? ""
        display = try container.decodeIfPresent(String.self, forKey: .display)
            ?? container.decodeIfPresent(String.self, forKey: .displayName)
            ?? (!cid.isEmpty ? cid : "Virtual Circuit #\(id)")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(cid, forKey: .cid)
        try container.encode(display, forKey: .display)
    }

    private enum CodingKeys: String, CodingKey {
        case id, cid, display, displayName
    }
}

struct NestedInterface: Codable, Hashable, Sendable {
    let id: Int
    let name: String
    let display: String
    let device: NestedDevice?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .display)
            ?? "Interface #\(id)"
        display = try container.decodeIfPresent(String.self, forKey: .display) ?? name
        device = try container.decodeIfPresent(NestedDevice.self, forKey: .device)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(display, forKey: .display)
        try container.encodeIfPresent(device, forKey: .device)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, display, device
    }
}

struct VirtualCircuit: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let cid: String
    let display: String
    let providerNetwork: NestedProviderNetwork?
    let circuitType: VirtualCircuitType
    let status: StatusValue
    let description: String
    let comments: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        cid = try container.decodeIfPresent(String.self, forKey: .cid) ?? ""
        display = try container.decodeIfPresent(String.self, forKey: .display)
            ?? container.decodeIfPresent(String.self, forKey: .displayName)
            ?? (!cid.isEmpty ? cid : "Virtual Circuit #\(id)")
        providerNetwork = try container.decodeIfPresent(NestedProviderNetwork.self, forKey: .providerNetwork)
        circuitType = try container.decode(VirtualCircuitType.self, forKey: .circuitType)
        status = try container.decode(StatusValue.self, forKey: .status)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        comments = try container.decodeIfPresent(String.self, forKey: .comments) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(cid, forKey: .cid)
        try container.encode(display, forKey: .display)
        try container.encodeIfPresent(providerNetwork, forKey: .providerNetwork)
        try container.encode(circuitType, forKey: .circuitType)
        try container.encode(status, forKey: .status)
        try container.encode(description, forKey: .description)
        try container.encode(comments, forKey: .comments)
    }

    private enum CodingKeys: String, CodingKey {
        case id, cid, display, displayName, providerNetwork, status, description, comments
        case circuitType = "type"
    }
}

struct VirtualCircuitTermination: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let display: String
    let virtualCircuit: NestedVirtualCircuit
    let interface: NestedInterface
    let role: StatusValue?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        display = try container.decodeIfPresent(String.self, forKey: .display)
            ?? container.decodeIfPresent(String.self, forKey: .displayName)
            ?? "Termination #\(id)"
        virtualCircuit = try container.decode(NestedVirtualCircuit.self, forKey: .virtualCircuit)
        interface = try container.decode(NestedInterface.self, forKey: .interface)
        role = try container.decodeIfPresent(StatusValue.self, forKey: .role)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(display, forKey: .display)
        try container.encode(virtualCircuit, forKey: .virtualCircuit)
        try container.encode(interface, forKey: .interface)
        try container.encodeIfPresent(role, forKey: .role)
    }

    private enum CodingKeys: String, CodingKey {
        case id, display, displayName, virtualCircuit, interface, role
    }
}
