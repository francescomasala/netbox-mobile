import Foundation

struct CachedSearchResults: Codable, Sendable {
    let devices: [Device]
    let prefixes: [Prefix]
    let ipAddresses: [IPAddress]
    let savedAt: Date

    var isEmpty: Bool {
        devices.isEmpty && prefixes.isEmpty && ipAddresses.isEmpty
    }
}

struct CachedDeviceDetail: Codable, Sendable {
    let device: Device
    let interfaces: [Interface]
    let savedAt: Date
}

struct CachedPrefixDetail: Codable, Sendable {
    let prefix: Prefix
    let ipAddresses: [IPAddress]
    let savedAt: Date
}

struct CachedCircuitDetail: Codable, Sendable {
    let circuit: Circuit
    let terminations: [CircuitTermination]
    let savedAt: Date
}

struct CachedVirtualCircuitDetail: Codable, Sendable {
    let circuit: VirtualCircuit
    let terminations: [VirtualCircuitTermination]
    let savedAt: Date
}

@MainActor
final class OfflineCacheStore {
    private struct SearchEntry: Codable, Sendable {
        let query: String
        let results: CachedSearchResults
    }

    private enum Keys {
        static let searchEntries = "offline.search.entries.v1"
        static let deviceDetails = "offline.device.details.v1"
        static let prefixDetails = "offline.prefix.details.v1"
        static let circuitDetails = "offline.circuit.details.v1"
        static let virtualCircuitDetails = "offline.virtualCircuit.details.v1"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let maxSearchEntries = 50

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func cachedSearchResults(for query: String) -> CachedSearchResults? {
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty else { return nil }
        return (load([SearchEntry].self, forKey: Keys.searchEntries) ?? [])
            .first { $0.query == normalizedQuery }?
            .results
    }

    func saveSearchResults(_ results: CachedSearchResults, for query: String) {
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty else { return }

        var entries = (load([SearchEntry].self, forKey: Keys.searchEntries) ?? [])
            .filter { $0.query != normalizedQuery }
        entries.insert(SearchEntry(query: normalizedQuery, results: results), at: 0)
        save(Array(entries.prefix(maxSearchEntries)), forKey: Keys.searchEntries)
    }

    func cachedDeviceDetail(id: Int) -> CachedDeviceDetail? {
        (load([String: CachedDeviceDetail].self, forKey: Keys.deviceDetails) ?? [:])[String(id)]
    }

    func saveDeviceDetail(device: Device, interfaces: [Interface]) {
        var details = load([String: CachedDeviceDetail].self, forKey: Keys.deviceDetails) ?? [:]
        details[String(device.id)] = CachedDeviceDetail(device: device, interfaces: interfaces, savedAt: Date())
        save(details, forKey: Keys.deviceDetails)
    }

    func cachedPrefixDetail(id: Int) -> CachedPrefixDetail? {
        (load([String: CachedPrefixDetail].self, forKey: Keys.prefixDetails) ?? [:])[String(id)]
    }

    func savePrefixDetail(prefix: Prefix, ipAddresses: [IPAddress]) {
        var details = load([String: CachedPrefixDetail].self, forKey: Keys.prefixDetails) ?? [:]
        details[String(prefix.id)] = CachedPrefixDetail(prefix: prefix, ipAddresses: ipAddresses, savedAt: Date())
        save(details, forKey: Keys.prefixDetails)
    }

    func cachedCircuitDetail(id: Int) -> CachedCircuitDetail? {
        (load([String: CachedCircuitDetail].self, forKey: Keys.circuitDetails) ?? [:])[String(id)]
    }

    func saveCircuitDetail(circuit: Circuit, terminations: [CircuitTermination]) {
        var details = load([String: CachedCircuitDetail].self, forKey: Keys.circuitDetails) ?? [:]
        details[String(circuit.id)] = CachedCircuitDetail(circuit: circuit, terminations: terminations, savedAt: Date())
        save(details, forKey: Keys.circuitDetails)
    }

    func cachedVirtualCircuitDetail(id: Int) -> CachedVirtualCircuitDetail? {
        (load([String: CachedVirtualCircuitDetail].self, forKey: Keys.virtualCircuitDetails) ?? [:])[String(id)]
    }

    func saveVirtualCircuitDetail(circuit: VirtualCircuit, terminations: [VirtualCircuitTermination]) {
        var details = load([String: CachedVirtualCircuitDetail].self, forKey: Keys.virtualCircuitDetails) ?? [:]
        details[String(circuit.id)] = CachedVirtualCircuitDetail(circuit: circuit, terminations: terminations, savedAt: Date())
        save(details, forKey: Keys.virtualCircuitDetails)
    }

    private func normalize(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    private func save<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
