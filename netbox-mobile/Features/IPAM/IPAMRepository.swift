import Foundation

struct CreateIPAddressRequest: Encodable, Sendable {
    let address: String
    let status: String
    let dnsName: String?
    let description: String?
    let assignedObjectType: String?
    let assignedObjectId: Int?
}

protocol IPAMRepositoryProtocol: Sendable {
    func fetchPrefixes(vrfId: Int?, family: Int?, query: String?) async throws -> PagedResult<Prefix>
    func fetchIPAddresses(prefixId: Int?, query: String?) async throws -> [IPAddress]
    func createIPAddress(_ request: CreateIPAddressRequest) async throws -> IPAddress
}

actor IPAMRepository: IPAMRepositoryProtocol {
    private let client: NetBoxClient
    private let pageLimit = 100
    private let resultCap = 500

    init(client: NetBoxClient) {
        self.client = client
    }

    func fetchPrefixes(vrfId: Int?, family: Int?, query: String?) async throws -> PagedResult<Prefix> {
        var queryItems: [URLQueryItem] = []
        if let vrfId { queryItems.append(URLQueryItem(name: "vrf_id", value: String(vrfId))) }
        if let family { queryItems.append(URLQueryItem(name: "family", value: String(family))) }
        if let query, !query.isEmpty { queryItems.append(URLQueryItem(name: "q", value: query)) }
        return try await fetchAll(endpoint: "ipam/prefixes", baseQueryItems: queryItems)
    }

    func fetchIPAddresses(prefixId: Int?, query: String?) async throws -> [IPAddress] {
        // Guard against fetching all IPs with no filter
        guard prefixId != nil || (query != nil && !query!.isEmpty) else {
            return []
        }

        var queryItems: [URLQueryItem] = []
        if let prefixId {
            let prefix: Prefix = try await client.get("ipam/prefixes/\(prefixId)")
            queryItems.append(URLQueryItem(name: "parent", value: prefix.prefix))
        }
        if let query, !query.isEmpty {
            queryItems.append(URLQueryItem(name: "q", value: query))
        }

        let result: PagedResult<IPAddress> = try await fetchAll(
            endpoint: "ipam/ip-addresses",
            baseQueryItems: queryItems
        )
        return result.items
    }

    func createIPAddress(_ request: CreateIPAddressRequest) async throws -> IPAddress {
        try await client.post("ipam/ip-addresses", body: request)
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
