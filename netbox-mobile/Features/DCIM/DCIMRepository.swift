import Foundation

protocol DCIMRepositoryProtocol: Sendable {
    func fetchDevices(siteId: Int?, status: String?, query: String?, assetTag: String?) async throws -> PagedResult<Device>
    func fetchDevice(id: Int) async throws -> Device
    func fetchInterfaces(deviceId: Int) async throws -> [Interface]
    func updateDeviceStatus(deviceId: Int, status: String) async throws -> Device
}

actor DCIMRepository: DCIMRepositoryProtocol {
    private let client: NetBoxClient
    private let pageLimit = 100
    private let resultCap = 500

    init(client: NetBoxClient) {
        self.client = client
    }

    func fetchDevices(siteId: Int?, status: String?, query: String?, assetTag: String?) async throws -> PagedResult<Device> {
        var queryItems: [URLQueryItem] = []
        if let siteId { queryItems.append(URLQueryItem(name: "site_id", value: String(siteId))) }
        if let status { queryItems.append(URLQueryItem(name: "status", value: status)) }
        if let query, !query.isEmpty { queryItems.append(URLQueryItem(name: "q", value: query)) }
        if let assetTag, !assetTag.isEmpty { queryItems.append(URLQueryItem(name: "asset_tag", value: assetTag)) }
        return try await fetchAll(endpoint: "dcim/devices", baseQueryItems: queryItems)
    }

    func fetchDevice(id: Int) async throws -> Device {
        try await client.get("dcim/devices/\(id)")
    }

    func fetchInterfaces(deviceId: Int) async throws -> [Interface] {
        let queryItems = [URLQueryItem(name: "device_id", value: String(deviceId))]
        let result: PagedResult<Interface> = try await fetchAll(
            endpoint: "dcim/interfaces",
            baseQueryItems: queryItems
        )
        return result.items
    }

    func updateDeviceStatus(deviceId: Int, status: String) async throws -> Device {
        try await client.patch(
            "dcim/devices/\(deviceId)",
            body: DeviceStatusUpdateRequest(status: status)
        )
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

private struct DeviceStatusUpdateRequest: Encodable, Sendable {
    let status: String
}
