import Foundation

protocol IPAMRepositoryProtocol: Sendable {
    func fetchPrefixes(vrfId: Int?, family: Int?) async throws -> [Prefix]
    func fetchIPAddresses(prefixId: Int) async throws -> [IPAddress]
}

actor IPAMRepository: IPAMRepositoryProtocol {
    private let client: NetBoxClient
    private let pageLimit = 100

    init(client: NetBoxClient) {
        self.client = client
    }

    func fetchPrefixes(vrfId: Int?, family: Int?) async throws -> [Prefix] {
        var queryItems: [URLQueryItem] = []

        if let vrfId {
            queryItems.append(URLQueryItem(name: "vrf_id", value: String(vrfId)))
        }

        if let family {
            queryItems.append(URLQueryItem(name: "family", value: String(family)))
        }

        return try await fetchAll(endpoint: "ipam/prefixes", baseQueryItems: queryItems)
    }

    func fetchIPAddresses(prefixId: Int) async throws -> [IPAddress] {
        let prefix: Prefix = try await client.get("ipam/prefixes/\(prefixId)")
        let queryItems = [
            URLQueryItem(name: "parent", value: prefix.prefix)
        ]

        return try await fetchAll(endpoint: "ipam/ip-addresses", baseQueryItems: queryItems)
    }

    private func fetchAll<T: Decodable & Sendable>(
        endpoint: String,
        baseQueryItems: [URLQueryItem]
    ) async throws -> [T] {
        var offset = 0
        var results: [T] = []

        while true {
            try Task.checkCancellation()

            let queryItems = baseQueryItems + [
                URLQueryItem(name: "limit", value: String(pageLimit)),
                URLQueryItem(name: "offset", value: String(offset))
            ]

            let page: PagedResponse<T> = try await client.get(endpoint, queryItems: queryItems)
            results.append(contentsOf: page.results)

            guard page.next != nil, !page.results.isEmpty, results.count < page.count else {
                return results
            }

            offset += pageLimit
        }
    }
}
