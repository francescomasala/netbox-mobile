import Foundation

protocol CircuitsRepositoryProtocol: Sendable {
    func fetchCircuits(query: String?) async throws -> PagedResult<Circuit>
    func fetchCircuit(id: Int) async throws -> Circuit
    func fetchCircuitTerminations(circuitId: Int) async throws -> [CircuitTermination]
    func fetchVirtualCircuits(query: String?) async throws -> PagedResult<VirtualCircuit>
    func fetchVirtualCircuit(id: Int) async throws -> VirtualCircuit
    func fetchVirtualCircuitTerminations(virtualCircuitId: Int) async throws -> [VirtualCircuitTermination]
}

actor CircuitsRepository: CircuitsRepositoryProtocol {
    private let client: NetBoxClient
    private let pageLimit = 100
    private let resultCap = 500

    init(client: NetBoxClient) {
        self.client = client
    }

    func fetchCircuits(query: String?) async throws -> PagedResult<Circuit> {
        var queryItems: [URLQueryItem] = []
        if let query, !query.isEmpty {
            queryItems.append(URLQueryItem(name: "q", value: query))
        }
        return try await fetchAll(endpoint: "circuits/circuits", baseQueryItems: queryItems)
    }

    func fetchCircuit(id: Int) async throws -> Circuit {
        try await client.get("circuits/circuits/\(id)")
    }

    func fetchCircuitTerminations(circuitId: Int) async throws -> [CircuitTermination] {
        let result: PagedResult<CircuitTermination> = try await fetchAll(
            endpoint: "circuits/circuit-terminations",
            baseQueryItems: [URLQueryItem(name: "circuit_id", value: String(circuitId))]
        )
        return result.items
    }

    func fetchVirtualCircuits(query: String?) async throws -> PagedResult<VirtualCircuit> {
        var queryItems: [URLQueryItem] = []
        if let query, !query.isEmpty {
            queryItems.append(URLQueryItem(name: "q", value: query))
        }
        return try await fetchAll(endpoint: "circuits/virtual-circuits", baseQueryItems: queryItems)
    }

    func fetchVirtualCircuit(id: Int) async throws -> VirtualCircuit {
        try await client.get("circuits/virtual-circuits/\(id)")
    }

    func fetchVirtualCircuitTerminations(virtualCircuitId: Int) async throws -> [VirtualCircuitTermination] {
        let result: PagedResult<VirtualCircuitTermination> = try await fetchAll(
            endpoint: "circuits/virtual-circuit-terminations",
            baseQueryItems: [URLQueryItem(name: "virtual_circuit_id", value: String(virtualCircuitId))]
        )
        return result.items
    }

    private func fetchAll<T: Decodable & Sendable>(
        endpoint: String,
        baseQueryItems: [URLQueryItem]
    ) async throws -> PagedResult<T> {
        var offset = 0
        var results: [T] = []
        var totalCount = 0

        while true {
            try Task.checkCancellation()

            let queryItems = baseQueryItems + [
                URLQueryItem(name: "limit", value: String(pageLimit)),
                URLQueryItem(name: "offset", value: String(offset))
            ]

            let page: PagedResponse<T> = try await client.get(endpoint, queryItems: queryItems)
            totalCount = page.count
            results.append(contentsOf: page.results)

            guard page.next != nil,
                  !page.results.isEmpty,
                  results.count < page.count,
                  results.count < resultCap else {
                return PagedResult(items: results, totalCount: totalCount)
            }

            offset += pageLimit
        }
    }
}
