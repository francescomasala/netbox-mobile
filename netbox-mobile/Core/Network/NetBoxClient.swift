import Foundation

actor NetBoxClient {
    private let connection: Connection
    private let keychain: KeychainWrapper
    private let session: URLSession
    private let sessionDelegate: SelfSignedCertificateDelegate?

    init(connection: Connection, keychain: KeychainWrapper) {
        self.connection = connection
        self.keychain = keychain

        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = true

        if connection.allowSelfSignedCertificates {
            let delegate = SelfSignedCertificateDelegate(allowsSelfSignedCertificates: true)
            session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
            sessionDelegate = delegate
        } else {
            session = URLSession(configuration: configuration)
            sessionDelegate = nil
        }
    }

    init(connection: Connection, keychain: KeychainWrapper, session: URLSession) {
        self.connection = connection
        self.keychain = keychain
        self.session = session
        sessionDelegate = nil
    }

    func get<T: Decodable & Sendable>(_ endpoint: String, queryItems: [URLQueryItem] = []) async throws -> T {
        try await send(endpoint, method: "GET", queryItems: queryItems, bodyData: nil)
    }

    func post<Response: Decodable & Sendable, Body: Encodable & Sendable>(
        _ endpoint: String,
        body: Body,
        queryItems: [URLQueryItem] = []
    ) async throws -> Response {
        let bodyData = try encode(body)
        return try await send(endpoint, method: "POST", queryItems: queryItems, bodyData: bodyData)
    }

    func patch<Response: Decodable & Sendable, Body: Encodable & Sendable>(
        _ endpoint: String,
        body: Body,
        queryItems: [URLQueryItem] = []
    ) async throws -> Response {
        let bodyData = try encode(body)
        return try await send(endpoint, method: "PATCH", queryItems: queryItems, bodyData: bodyData)
    }

    private func send<T: Decodable & Sendable>(
        _ endpoint: String,
        method: String,
        queryItems: [URLQueryItem],
        bodyData: Data?
    ) async throws -> T {
        try Task.checkCancellation()

        let token = try await keychain.load(for: connection.id)
        let url = try Self.apiURL(baseURL: connection.baseURL, endpoint: endpoint, queryItems: queryItems)

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = bodyData
        request.setValue(connection.tokenVersion.authorizationHeader(for: token), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError {
            if error.code == .cancelled {
                throw CancellationError()
            }

            throw APIError.networkUnavailable
        }

        try Task.checkCancellation()

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkUnavailable
        }

        if let apiError = Self.apiError(for: httpResponse.statusCode) {
            throw apiError
        }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingFailed(underlying: error)
        }
    }

    private func encode<Body: Encodable & Sendable>(_ body: Body) throws -> Data {
        do {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            return try encoder.encode(body)
        } catch {
            throw APIError.encodingFailed(underlying: error)
        }
    }

    nonisolated static func apiURL(
        baseURL: URL,
        endpoint: String,
        queryItems: [URLQueryItem] = []
    ) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }

        let trimmedEndpoint = endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let basePath = components.percentEncodedPath
        let normalizedBasePath: String
        if basePath == "/" {
            normalizedBasePath = ""
        } else if basePath.hasSuffix("/") {
            normalizedBasePath = String(basePath.dropLast())
        } else {
            normalizedBasePath = basePath
        }

        if trimmedEndpoint.isEmpty {
            components.percentEncodedPath = "\(normalizedBasePath)/api/"
        } else {
            components.percentEncodedPath = "\(normalizedBasePath)/api/\(trimmedEndpoint)/"
        }

        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        return url
    }

    nonisolated static func apiError(for statusCode: Int) -> APIError? {
        switch statusCode {
        case 200...299:
            nil
        case 401:
            .unauthorized
        case 403:
            .forbidden
        case 404:
            .notFound
        default:
            .serverError(statusCode: statusCode)
        }
    }
}

final class SelfSignedCertificateDelegate: NSObject, URLSessionDelegate {
    private let allowsSelfSignedCertificates: Bool

    init(allowsSelfSignedCertificates: Bool) {
        self.allowsSelfSignedCertificates = allowsSelfSignedCertificates
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard
            allowsSelfSignedCertificates,
            challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            let serverTrust = challenge.protectionSpace.serverTrust
        else {
            return (.performDefaultHandling, nil)
        }

        return (.useCredential, URLCredential(trust: serverTrust))
    }
}
