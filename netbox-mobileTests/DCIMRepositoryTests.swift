import Foundation
import os
import Testing
@testable import netbox_mobile

@Suite(.serialized)
struct DCIMRepositoryTests {

    // MARK: - Fixtures

    private static let fullDeviceJSON = """
    {
        "id": 1,
        "name": "core-sw-01",
        "display": "core-sw-01",
        "device_type": {
            "id": 10,
            "manufacturer": {"id": 1, "name": "Cisco", "slug": "cisco"},
            "model": "Catalyst 9300",
            "slug": "catalyst-9300",
            "u_height": 1.0
        },
        "site": {"id": 5, "name": "AMS-DC1", "slug": "ams-dc1"},
        "rack": {"id": 3, "name": "Rack-A1", "display": "AMS-DC1 > Rack-A1"},
        "position": 42.0,
        "status": {"value": "active", "label": "Active"},
        "primary_ip": {"id": 100, "address": "10.0.0.1/24", "display": "10.0.0.1/24"},
        "primary_ip4": {"id": 100, "address": "10.0.0.1/24", "display": "10.0.0.1/24"},
        "primary_ip6": {"id": 101, "address": "2001:db8::1/64", "display": "2001:db8::1/64"},
        "asset_tag": "TAG-0001",
        "serial": "SN123456",
        "description": "Core switch",
        "comments": "Replaced 2024-01"
    }
    """

    private static let minimalDeviceJSON = """
    {
        "id": 2,
        "name": null,
        "display": "Unknown Device",
        "device_type": {
            "id": 11,
            "manufacturer": {"id": 2, "name": "Juniper", "slug": "juniper"},
            "model": "EX4300",
            "slug": "ex4300",
            "u_height": 1.0
        },
        "site": {"id": 6, "name": "AMS-DC2", "slug": "ams-dc2"},
        "rack": null,
        "position": null,
        "status": {"value": "planned", "label": "Planned"},
        "primary_ip": null,
        "primary_ip4": null,
        "primary_ip6": null,
        "asset_tag": null,
        "serial": "",
        "description": "",
        "comments": ""
    }
    """

    private static let briefDeviceTypeJSON = """
    {
        "id": 3,
        "name": "edge-rtr-01",
        "display_name": "edge-rtr-01",
        "device_type": {
            "id": 12,
            "url": "https://netbox.example/api/dcim/device-types/12/",
            "display": "Cisco ISR 4451",
            "manufacturer": {
                "id": 1,
                "url": "https://netbox.example/api/dcim/manufacturers/1/",
                "display": "Cisco",
                "name": "Cisco",
                "slug": "cisco",
                "description": ""
            },
            "model": "ISR 4451",
            "slug": "isr-4451",
            "description": "",
            "device_count": 4
        },
        "site": {
            "id": 5,
            "url": "https://netbox.example/api/dcim/sites/5/",
            "display": "AMS-DC1",
            "name": "AMS-DC1",
            "slug": "ams-dc1",
            "description": ""
        },
        "rack": null,
        "position": null,
        "status": {"value": "active", "label": "Active"},
        "primary_ip": null,
        "primary_ip4": null,
        "primary_ip6": null,
        "asset_tag": null,
        "serial": "",
        "description": "",
        "comments": ""
    }
    """

    private static let interfaceJSON = """
    {
        "id": 200,
        "device": {"id": 1, "name": "core-sw-01", "display": "core-sw-01"},
        "name": "GigabitEthernet0/0",
        "type": {"value": "1000base-t", "label": "1000BASE-T (1GE)"},
        "enabled": true,
        "mtu": null,
        "mac_address": null,
        "description": "Uplink",
        "mode": null,
        "count_ipaddresses": 1
    }
    """

    // MARK: - Tests

    @Test func fetchDevicesDecodesFullDevice() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.setHandler { request in
            let response = try makeHTTPResponse(for: request, statusCode: 200)
            let body = """
            {
                "count": 1,
                "next": null,
                "previous": null,
                "results": [\(Self.fullDeviceJSON)]
            }
            """
            return (response, Data(body.utf8))
        }

        let client = try await Self.makeClient()
        let repository = DCIMRepository(client: client)
        let result = try await repository.fetchDevices(siteId: nil, status: nil, query: nil, assetTag: nil)

        #expect(result.items.count == 1)
        let device = try #require(result.items.first)
        #expect(device.id == 1)
        #expect(device.name == "core-sw-01")
        #expect(device.status.value == "active")
        #expect(device.rack?.name == "Rack-A1")
        #expect(device.primaryIp4?.address == "10.0.0.1/24")
        #expect(device.primaryIp6?.address == "2001:db8::1/64")
        #expect(device.assetTag == "TAG-0001")
        #expect(device.deviceType.manufacturer.name == "Cisco")
        #expect(result.totalCount == 1)
        #expect(!result.isTruncated)
    }

    @Test func fetchDevicesDecodesMinimalDevice() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.setHandler { request in
            let response = try makeHTTPResponse(for: request, statusCode: 200)
            let body = """
            {
                "count": 1,
                "next": null,
                "previous": null,
                "results": [\(Self.minimalDeviceJSON)]
            }
            """
            return (response, Data(body.utf8))
        }

        let client = try await Self.makeClient()
        let repository = DCIMRepository(client: client)
        let result = try await repository.fetchDevices(siteId: nil, status: nil, query: nil, assetTag: nil)

        let device = try #require(result.items.first)
        #expect(device.name == nil)
        #expect(device.display == "Unknown Device")
        #expect(device.rack == nil)
        #expect(device.position == nil)
        #expect(device.primaryIp == nil)
        #expect(device.assetTag == nil)
    }

    @Test func fetchDevicesDecodesBriefDeviceTypeWithoutHeight() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.setHandler { request in
            let response = try makeHTTPResponse(for: request, statusCode: 200)
            let body = """
            {
                "count": 1,
                "next": null,
                "previous": null,
                "results": [\(Self.briefDeviceTypeJSON)]
            }
            """
            return (response, Data(body.utf8))
        }

        let client = try await Self.makeClient()
        let repository = DCIMRepository(client: client)
        let result = try await repository.fetchDevices(siteId: nil, status: nil, query: nil, assetTag: nil)

        let device = try #require(result.items.first)
        #expect(device.display == "edge-rtr-01")
        #expect(device.deviceType.model == "ISR 4451")
        #expect(device.deviceType.manufacturer.name == "Cisco")
        #expect(device.deviceType.uHeight == nil)
    }

    @Test func fetchInterfacesDecodesNullableMTUAndMode() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.setHandler { request in
            let response = try makeHTTPResponse(for: request, statusCode: 200)
            let body = """
            {
                "count": 1,
                "next": null,
                "previous": null,
                "results": [\(Self.interfaceJSON)]
            }
            """
            return (response, Data(body.utf8))
        }

        let client = try await Self.makeClient()
        let repository = DCIMRepository(client: client)
        let interfaces = try await repository.fetchInterfaces(deviceId: 1)

        let iface = try #require(interfaces.first)
        #expect(iface.id == 200)
        #expect(iface.name == "GigabitEthernet0/0")
        #expect(iface.interfaceType.value == "1000base-t")
        #expect(iface.enabled)
        #expect(iface.mtu == nil)
        #expect(iface.mode == nil)
        #expect(iface.countIpaddresses == 1)
    }

    @Test func fetchDevicesSendsAssetTagQueryParam() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.setHandler { request in
            let response = try makeHTTPResponse(for: request, statusCode: 200)
            let body = """
            {
                "count": 0,
                "next": null,
                "previous": null,
                "results": []
            }
            """
            return (response, Data(body.utf8))
        }

        let client = try await Self.makeClient()
        let repository = DCIMRepository(client: client)
        _ = try await repository.fetchDevices(siteId: nil, status: nil, query: nil, assetTag: "TAG-0001")

        let request = try #require(MockURLProtocol.recordedRequests().first)
        let requestURL = try #require(request.url)
        let components = try #require(URLComponents(url: requestURL, resolvingAgainstBaseURL: false))
        let queryItems = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        #expect(queryItems["asset_tag"] == "TAG-0001")
    }

    @Test func fetchDevicesPaginatesAllPages() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.setHandler { request in
            guard
                let url = request.url,
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            else { throw URLError(.badURL) }

            let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
            let offset = query["offset"] ?? "0"
            let nextValue = offset == "0" ? "\"https://netbox.example/api/dcim/devices/?limit=100&offset=100\"" : "null"
            let id = offset == "0" ? 1 : 2
            let name = offset == "0" ? "sw-01" : "sw-02"

            let body = """
            {
                "count": 2,
                "next": \(nextValue),
                "previous": null,
                "results": [{
                    "id": \(id),
                    "name": "\(name)",
                    "display": "\(name)",
                    "device_type": {
                        "id": 10,
                        "manufacturer": {"id": 1, "name": "Cisco", "slug": "cisco"},
                        "model": "Catalyst 9300",
                        "slug": "catalyst-9300",
                        "u_height": 1.0
                    },
                    "site": {"id": 5, "name": "AMS-DC1", "slug": "ams-dc1"},
                    "rack": null,
                    "position": null,
                    "status": {"value": "active", "label": "Active"},
                    "primary_ip": null,
                    "primary_ip4": null,
                    "primary_ip6": null,
                    "asset_tag": null,
                    "serial": "",
                    "description": "",
                    "comments": ""
                }]
            }
            """
            let response = try makeHTTPResponse(for: request, statusCode: 200)
            return (response, Data(body.utf8))
        }

        let client = try await Self.makeClient()
        let repository = DCIMRepository(client: client)
        let result = try await repository.fetchDevices(siteId: nil, status: nil, query: nil, assetTag: nil)

        #expect(result.items.compactMap(\.name) == ["sw-01", "sw-02"])
        #expect(result.totalCount == 2)
        #expect(MockURLProtocol.recordedRequests().count == 2)
    }

    // MARK: - Helpers

    private static func makeClient() async throws -> NetBoxClient {
        let connectionID = UUID()
        let keychain = KeychainWrapper(service: "it.hyperbit.netboxmobile.tests.\(UUID().uuidString)")
        try await keychain.save(token: "test-token", for: connectionID)

        let connection = Connection(
            id: connectionID,
            name: "Test",
            baseURL: URL(string: "https://netbox.example")!
        )

        return NetBoxClient(connection: connection, keychain: keychain, session: mockSession())
    }

    private static func mockSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private func makeHTTPResponse(for request: URLRequest, statusCode: Int) throws -> HTTPURLResponse {
    guard
        let url = request.url,
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)
    else {
        throw URLError(.badServerResponse)
    }
    return response
}

private final class MockURLProtocol: URLProtocol {
    private struct State: Sendable {
        var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?
        var requests: [URLRequest] = []
    }

    private static let state = OSAllocatedUnfairLock(initialState: State())

    static func reset() {
        state.withLock { $0.handler = nil; $0.requests = [] }
    }

    static func setHandler(_ handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)) {
        state.withLock { $0.handler = handler }
    }

    static func recordedRequests() -> [URLRequest] {
        state.withLock { $0.requests }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let currentRequest = request
        let handler = Self.state.withLock { state in
            state.requests.append(currentRequest)
            return state.handler
        }

        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(currentRequest)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
