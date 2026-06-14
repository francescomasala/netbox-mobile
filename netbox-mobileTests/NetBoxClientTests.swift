import Foundation
import os
import Testing
@testable import netbox_mobile

@Suite(.serialized)
struct NetBoxClientTests {
    @Test func getBuildsAuthorizedRequestAndDecodesSnakeCaseResponse() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.setHandler { request in
            let response = try makeHTTPResponse(for: request, statusCode: 200)

            let body = """
            {
                "count": 1,
                "next": null,
                "previous": null,
                "results": [
                    {
                        "id": 1,
                        "prefix": "10.0.0.0/24",
                        "vrf": {"id": 10, "name": "Prod", "rd": "65000:10"},
                        "status": {"value": "active", "label": "Active"},
                        "description": "LAN",
                        "is_pool": true,
                        "family": {"value": 4, "label": "IPv4"},
                        "utilization": 42.0
                    }
                ]
            }
            """

            return (response, Data(body.utf8))
        }

        let connectionID = UUID()
        let keychain = KeychainWrapper(service: "it.hyperbit.netboxmobile.tests.\(UUID().uuidString)")
        try await keychain.save(token: "test-token", for: connectionID)

        let connection = Connection(
            id: connectionID,
            name: "Test",
            baseURL: try #require(URL(string: "https://netbox.example"))
        )

        let client = NetBoxClient(
            connection: connection,
            keychain: keychain,
            session: Self.mockSession()
        )

        let page: PagedResponse<Prefix> = try await client.get(
            "ipam/prefixes",
            queryItems: [URLQueryItem(name: "limit", value: "100")]
        )

        #expect(page.count == 1)
        #expect(page.results.first?.isPool == true)
        #expect(page.results.first?.vrf?.name == "Prod")

        let request = try #require(MockURLProtocol.recordedRequests().first)
        #expect(request.url?.absoluteString == "https://netbox.example/api/ipam/prefixes/?limit=100")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Token test-token")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

        try await keychain.delete(for: connectionID)
    }

    @Test func mapsUnauthorizedStatusToAPIError() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.setHandler { request in
            let response = try makeHTTPResponse(for: request, statusCode: 401)

            return (response, Data())
        }

        let client = try await Self.makeClient()

        do {
            let _: EmptyPayload = try await client.get("ipam/prefixes")
            #expect(Bool(false), "Expected unauthorized error")
        } catch APIError.unauthorized {
            #expect(true)
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }

    @Test func wrapsDecodingFailures() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.setHandler { request in
            let response = try makeHTTPResponse(for: request, statusCode: 200)

            return (response, Data(#"{"count":"not-an-int"}"#.utf8))
        }

        let client = try await Self.makeClient()

        do {
            let _: PagedResponse<Prefix> = try await client.get("ipam/prefixes")
            #expect(Bool(false), "Expected decoding failure")
        } catch APIError.decodingFailed {
            #expect(true)
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }

    @Test func repositoryFetchesAllPrefixPages() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.setHandler { request in
            guard
                let url = request.url,
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            else {
                throw URLError(.badURL)
            }
            let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
            let offset = query["offset"] ?? "0"

            #expect(components.path == "/api/ipam/prefixes/")
            #expect(query["family"] == "4")
            #expect(query["limit"] == "100")

            let nextValue = offset == "0" ? "\"https://netbox.example/api/ipam/prefixes/?limit=100&offset=100\"" : "null"
            let id = offset == "0" ? 1 : 2
            let prefix = offset == "0" ? "10.0.0.0/24" : "10.0.1.0/24"

            let body = """
            {
                "count": 2,
                "next": \(nextValue),
                "previous": null,
                "results": [
                    {
                        "id": \(id),
                        "prefix": "\(prefix)",
                        "vrf": null,
                        "status": {"value": "active", "label": "Active"},
                        "description": "",
                        "is_pool": false,
                        "family": {"value": 4, "label": "IPv4"},
                        "utilization": null
                    }
                ]
            }
            """

            let response = try makeHTTPResponse(for: request, statusCode: 200)

            return (response, Data(body.utf8))
        }

        let client = try await Self.makeClient()
        let repository = IPAMRepository(client: client)

        let result = try await repository.fetchPrefixes(vrfId: nil, family: 4, query: nil)

        #expect(result.items.map(\.prefix) == ["10.0.0.0/24", "10.0.1.0/24"])
        #expect(MockURLProtocol.recordedRequests().count == 2)
    }

    @Test func postEncodesSnakeCaseJSONBody() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.setHandler { request in
            let response = try makeHTTPResponse(for: request, statusCode: 201)
            let body = try requestBodyData(for: request)
            let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])

            #expect(request.httpMethod == "POST")
            #expect(request.url?.absoluteString == "https://netbox.example/api/ipam/ip-addresses/")
            #expect(object["dns_name"] as? String == "edge.example.net")
            #expect(object["assigned_object_id"] as? Int == 42)

            return (response, Data(#"{"ok":true}"#.utf8))
        }

        let client = try await Self.makeClient()
        let response: WriteProbeResponse = try await client.post(
            "ipam/ip-addresses",
            body: WriteProbePayload(dnsName: "edge.example.net", assignedObjectId: 42)
        )

        #expect(response.ok)
    }

    @Test func patchEncodesJSONBody() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.setHandler { request in
            let response = try makeHTTPResponse(for: request, statusCode: 200)
            let body = try requestBodyData(for: request)
            let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])

            #expect(request.httpMethod == "PATCH")
            #expect(request.url?.absoluteString == "https://netbox.example/api/dcim/devices/10/")
            #expect(object["status"] as? String == "offline")

            return (response, Data(#"{"ok":true}"#.utf8))
        }

        let client = try await Self.makeClient()
        let response: WriteProbeResponse = try await client.patch(
            "dcim/devices/10",
            body: StatusPatchPayload(status: "offline")
        )

        #expect(response.ok)
    }

    @Test func getUsesBearerAuthorizationHeaderForV2Token() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.setHandler { request in
            let response = try makeHTTPResponse(for: request, statusCode: 200)
            return (response, Data("{}".utf8))
        }

        let connectionID = UUID()
        let keychain = KeychainWrapper(service: "it.hyperbit.netboxmobile.tests.\(UUID().uuidString)")
        let v2Token = "nbt_abc123.secretplaintext"
        try await keychain.save(token: v2Token, for: connectionID)

        let connection = Connection(
            id: connectionID,
            name: "Test",
            baseURL: URL(string: "https://netbox.example")!,
            tokenVersion: .v2
        )

        let client = NetBoxClient(
            connection: connection,
            keychain: keychain,
            session: Self.mockSession()
        )

        let _: EmptyPayload = try await client.get("api/status")

        let request = try #require(MockURLProtocol.recordedRequests().first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer \(v2Token)")

        try await keychain.delete(for: connectionID)
    }

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

private struct EmptyPayload: Decodable, Sendable {}

private struct WriteProbePayload: Encodable, Sendable {
    let dnsName: String
    let assignedObjectId: Int
}

private struct StatusPatchPayload: Encodable, Sendable {
    let status: String
}

private struct WriteProbeResponse: Decodable, Sendable {
    let ok: Bool
}

private func requestBodyData(for request: URLRequest) throws -> Data {
    if let body = request.httpBody {
        return body
    }

    guard let stream = request.httpBodyStream else {
        throw URLError(.cannotDecodeContentData)
    }

    stream.open()
    defer { stream.close() }

    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 1024)

    while stream.hasBytesAvailable {
        let readCount = stream.read(&buffer, maxLength: buffer.count)
        if readCount < 0 {
            throw stream.streamError ?? URLError(.cannotDecodeContentData)
        }
        if readCount == 0 {
            break
        }
        data.append(buffer, count: readCount)
    }

    return data
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
        state.withLock { state in
            state.handler = nil
            state.requests = []
        }
    }

    static func setHandler(_ handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)) {
        state.withLock { state in
            state.handler = handler
        }
    }

    static func recordedRequests() -> [URLRequest] {
        state.withLock { state in
            state.requests
        }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

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
