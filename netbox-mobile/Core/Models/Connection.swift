import Foundation

enum TokenVersion: String, Codable, Sendable {
    case v1
    case v2

    static func detect(from token: String) -> TokenVersion {
        token.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("nbt_") ? .v2 : .v1
    }

    func authorizationHeader(for token: String) -> String {
        switch self {
        case .v1: "Token \(token)"
        case .v2: "Bearer \(token)"
        }
    }
}

struct Connection: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var baseURL: URL
    var isDefault: Bool
    var allowSelfSignedCertificates: Bool
    var tokenVersion: TokenVersion

    init(
        id: UUID = UUID(),
        name: String,
        baseURL: URL,
        isDefault: Bool = false,
        allowSelfSignedCertificates: Bool = false,
        tokenVersion: TokenVersion = .v1
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.isDefault = isDefault
        self.allowSelfSignedCertificates = allowSelfSignedCertificates
        self.tokenVersion = tokenVersion
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case baseURL
        case isDefault
        case allowSelfSignedCertificates
        case tokenVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        baseURL = try container.decode(URL.self, forKey: .baseURL)
        isDefault = try container.decode(Bool.self, forKey: .isDefault)
        allowSelfSignedCertificates = try container.decodeIfPresent(Bool.self, forKey: .allowSelfSignedCertificates) ?? false
        tokenVersion = try container.decodeIfPresent(TokenVersion.self, forKey: .tokenVersion) ?? .v1
    }
}

enum ConnectionStorage {
    static let connectionsKey = "it.hyperbit.netboxmobile.connections"
    static let selectedConnectionIDKey = "it.hyperbit.netboxmobile.selectedConnectionID"

    static func loadConnections(from defaults: UserDefaults = .standard) -> [Connection] {
        guard let data = defaults.data(forKey: connectionsKey) else {
            return []
        }

        return (try? JSONDecoder().decode([Connection].self, from: data)) ?? []
    }

    static func saveConnections(_ connections: [Connection], to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(connections) else {
            return
        }

        defaults.set(data, forKey: connectionsKey)
    }

    static func loadSelectedConnectionID(from defaults: UserDefaults = .standard) -> UUID? {
        guard let uuidString = defaults.string(forKey: selectedConnectionIDKey) else {
            return nil
        }

        return UUID(uuidString: uuidString)
    }

    static func saveSelectedConnectionID(_ id: UUID?, to defaults: UserDefaults = .standard) {
        if let id {
            defaults.set(id.uuidString, forKey: selectedConnectionIDKey)
        } else {
            defaults.removeObject(forKey: selectedConnectionIDKey)
        }
    }
}
