import Foundation

struct Provider: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let slug: String
    let description: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .display)
            ?? "Provider #\(id)"
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

struct CircuitType: Codable, Identifiable, Hashable, Sendable {
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

struct NestedCircuit: Codable, Hashable, Sendable {
    let id: Int
    let cid: String
    let display: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        cid = try container.decodeIfPresent(String.self, forKey: .cid) ?? ""
        display = try container.decodeIfPresent(String.self, forKey: .display)
            ?? container.decodeIfPresent(String.self, forKey: .displayName)
            ?? (!cid.isEmpty ? cid : "Circuit #\(id)")
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

struct NestedProviderNetwork: Codable, Hashable, Sendable {
    let id: Int
    let name: String
    let display: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .display)
            ?? "Provider Network #\(id)"
        display = try container.decodeIfPresent(String.self, forKey: .display) ?? name
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(display, forKey: .display)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, display
    }
}

private struct DistanceUnitValue: Codable, Hashable, Sendable {
    let value: String?
    let label: String?
}

struct Circuit: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let cid: String
    let display: String
    let provider: Provider
    let circuitType: CircuitType
    let status: StatusValue
    let installDate: String?
    let terminationDate: String?
    let commitRate: Int?
    let distance: Double?
    let distanceUnit: String?
    let description: String
    let comments: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        cid = try container.decodeIfPresent(String.self, forKey: .cid) ?? ""
        display = try container.decodeIfPresent(String.self, forKey: .display)
            ?? container.decodeIfPresent(String.self, forKey: .displayName)
            ?? (!cid.isEmpty ? cid : "Circuit #\(id)")
        provider = try container.decode(Provider.self, forKey: .provider)
        circuitType = try container.decode(CircuitType.self, forKey: .circuitType)
        status = try container.decode(StatusValue.self, forKey: .status)
        installDate = try container.decodeIfPresent(String.self, forKey: .installDate)
        terminationDate = try container.decodeIfPresent(String.self, forKey: .terminationDate)
        commitRate = try container.decodeIfPresent(Int.self, forKey: .commitRate)
        distance = try container.decodeIfPresent(Double.self, forKey: .distance)
        distanceUnit = Self.decodeDistanceUnit(from: container)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        comments = try container.decodeIfPresent(String.self, forKey: .comments) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(cid, forKey: .cid)
        try container.encode(display, forKey: .display)
        try container.encode(provider, forKey: .provider)
        try container.encode(circuitType, forKey: .circuitType)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(installDate, forKey: .installDate)
        try container.encodeIfPresent(terminationDate, forKey: .terminationDate)
        try container.encodeIfPresent(commitRate, forKey: .commitRate)
        try container.encodeIfPresent(distance, forKey: .distance)
        try container.encodeIfPresent(distanceUnit, forKey: .distanceUnit)
        try container.encode(description, forKey: .description)
        try container.encode(comments, forKey: .comments)
    }

    private enum CodingKeys: String, CodingKey {
        case id, cid, display, displayName, provider, status, installDate, terminationDate
        case circuitType = "type"
        case commitRate, distance, distanceUnit, description, comments
    }

    private static func decodeDistanceUnit(from container: KeyedDecodingContainer<CodingKeys>) -> String? {
        if let stringValue = try? container.decodeIfPresent(String.self, forKey: .distanceUnit) {
            return stringValue
        }

        if let objectValue = try? container.decodeIfPresent(DistanceUnitValue.self, forKey: .distanceUnit) {
            if let value = objectValue.value, !value.isEmpty {
                return value
            }
            return objectValue.label
        }

        return nil
    }
}

struct CircuitTermination: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let display: String
    let circuit: NestedCircuit
    let termSide: String
    let terminationType: String?
    let terminationId: Int?
    let site: NestedSite?
    let providerNetwork: NestedProviderNetwork?
    let portSpeed: Int?
    let upstreamSpeed: Int?
    let xconnectId: String
    let markConnected: Bool
    let description: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        display = try container.decodeIfPresent(String.self, forKey: .display)
            ?? container.decodeIfPresent(String.self, forKey: .displayName)
            ?? "Termination #\(id)"
        circuit = try container.decode(NestedCircuit.self, forKey: .circuit)
        termSide = try container.decodeIfPresent(String.self, forKey: .termSide) ?? ""
        terminationType = try container.decodeIfPresent(String.self, forKey: .terminationType)
        terminationId = try container.decodeIfPresent(Int.self, forKey: .terminationId)
        site = try container.decodeIfPresent(NestedSite.self, forKey: .site)
        providerNetwork = try container.decodeIfPresent(NestedProviderNetwork.self, forKey: .providerNetwork)
        portSpeed = try container.decodeIfPresent(Int.self, forKey: .portSpeed)
        upstreamSpeed = try container.decodeIfPresent(Int.self, forKey: .upstreamSpeed)
        xconnectId = try container.decodeIfPresent(String.self, forKey: .xconnectId) ?? ""
        markConnected = try container.decodeIfPresent(Bool.self, forKey: .markConnected) ?? false
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(display, forKey: .display)
        try container.encode(circuit, forKey: .circuit)
        try container.encode(termSide, forKey: .termSide)
        try container.encodeIfPresent(terminationType, forKey: .terminationType)
        try container.encodeIfPresent(terminationId, forKey: .terminationId)
        try container.encodeIfPresent(site, forKey: .site)
        try container.encodeIfPresent(providerNetwork, forKey: .providerNetwork)
        try container.encodeIfPresent(portSpeed, forKey: .portSpeed)
        try container.encodeIfPresent(upstreamSpeed, forKey: .upstreamSpeed)
        try container.encode(xconnectId, forKey: .xconnectId)
        try container.encode(markConnected, forKey: .markConnected)
        try container.encode(description, forKey: .description)
    }

    private enum CodingKeys: String, CodingKey {
        case id, display, displayName, circuit, termSide, terminationType, terminationId, site
        case providerNetwork, portSpeed, upstreamSpeed, xconnectId, markConnected, description
    }
}
