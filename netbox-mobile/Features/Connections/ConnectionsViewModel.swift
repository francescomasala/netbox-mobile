import Foundation
import Observation

@MainActor
@Observable
final class ConnectionsViewModel {
    var connections: [Connection] = []
    var selectedConnectionID: UUID?
    var isTestingConnection = false
    var isPresentingSetup = false

    @ObservationIgnored private let keychain: KeychainWrapper
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let urlSession: URLSession

    init(
        keychain: KeychainWrapper = KeychainWrapper(),
        defaults: UserDefaults = .standard,
        urlSession: URLSession = .shared
    ) {
        self.keychain = keychain
        self.defaults = defaults
        self.urlSession = urlSession
        load()
    }

    var selectedConnection: Connection? {
        if let selectedConnectionID,
           let connection = connections.first(where: { $0.id == selectedConnectionID }) {
            return connection
        }

        return connections.first(where: \.isDefault) ?? connections.first
    }

    func load() {
        connections = ConnectionStorage.loadConnections(from: defaults)
        selectedConnectionID = ConnectionStorage.loadSelectedConnectionID(from: defaults)

        if selectedConnectionID == nil {
            selectedConnectionID = connections.first(where: \.isDefault)?.id
        }
    }

    func saveConnection(
        name: String,
        netBoxURLString: String,
        apiToken: String,
        tokenVersion: TokenVersion,
        ignoreSelfSignedCertificates: Bool
    ) async throws {
        let baseURL = try NetBoxConnectionSetup.validatedBaseURL(from: netBoxURLString)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToken = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedToken.isEmpty else {
            throw APIError.invalidURL
        }

        isTestingConnection = true
        defer { isTestingConnection = false }

        try await testConnection(
            url: baseURL,
            token: trimmedToken,
            tokenVersion: tokenVersion,
            allowSelfSignedCertificates: ignoreSelfSignedCertificates
        )

        let connection = Connection(
            name: trimmedName.isEmpty ? NetBoxConnectionSetup.defaultName(for: baseURL) : trimmedName,
            baseURL: baseURL,
            isDefault: connections.isEmpty,
            allowSelfSignedCertificates: ignoreSelfSignedCertificates,
            tokenVersion: tokenVersion
        )

        try await keychain.save(token: trimmedToken, for: connection.id)

        connections.append(connection)
        selectedConnectionID = selectedConnectionID ?? connection.id
        persist()
        isPresentingSetup = false
    }

    func deleteConnections(at offsets: IndexSet) async {
        let deletedConnections = offsets.map { connections[$0] }
        for index in offsets.sorted(by: >) {
            connections.remove(at: index)
        }

        for connection in deletedConnections {
            try? await keychain.delete(for: connection.id)
        }

        if let selectedConnectionID, deletedConnections.contains(where: { $0.id == selectedConnectionID }) {
            self.selectedConnectionID = connections.first?.id
        }

        if !connections.contains(where: \.isDefault), let first = connections.first {
            setDefaultConnection(id: first.id)
        }

        persist()
        await refreshSetupPresentation()
    }

    func delete(_ connection: Connection) async {
        guard let index = connections.firstIndex(of: connection) else {
            return
        }

        await deleteConnections(at: IndexSet(integer: index))
    }

    func select(_ connection: Connection) async {
        selectedConnectionID = connection.id
        persistSelectedConnection()
        await refreshSetupPresentation()
    }

    func refreshSetupPresentation() async {
        isPresentingSetup = await setupIsRequired()
    }

    func setupIsRequired() async -> Bool {
        guard let connection = selectedConnection else {
            return true
        }

        guard
            let scheme = connection.baseURL.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            connection.baseURL.host != nil
        else {
            return true
        }

        do {
            let token = try await keychain.load(for: connection.id)
            return token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } catch {
            return true
        }
    }

    func repository(for connection: Connection) -> IPAMRepository {
        IPAMRepository(client: NetBoxClient(connection: connection, keychain: keychain))
    }

    func testConnection(url: URL, token: String) async throws {
        try await testConnection(
            url: url,
            token: token,
            tokenVersion: .detect(from: token),
            allowSelfSignedCertificates: false
        )
    }

    func testConnection(
        url: URL,
        token: String,
        tokenVersion: TokenVersion,
        allowSelfSignedCertificates: Bool
    ) async throws {
        let statusURL = try NetBoxClient.apiURL(baseURL: url, endpoint: "status")
        var request = URLRequest(url: statusURL, timeoutInterval: 15)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedToken.isEmpty {
            request.setValue(tokenVersion.authorizationHeader(for: trimmedToken), forHTTPHeaderField: "Authorization")
        }

        let session: URLSession
        if allowSelfSignedCertificates {
            let configuration = URLSessionConfiguration.ephemeral
            let delegate = SelfSignedCertificateDelegate(allowsSelfSignedCertificates: true)
            session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        } else {
            session = urlSession
        }

        let (_, response): (Data, URLResponse)
        do {
            (_, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError {
            if error.code == .cancelled {
                throw CancellationError()
            }

            throw APIError.networkUnavailable
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkUnavailable
        }

        if let apiError = NetBoxClient.apiError(for: httpResponse.statusCode) {
            throw apiError
        }
    }

    private func setDefaultConnection(id: UUID) {
        connections = connections.map { connection in
            var updatedConnection = connection
            updatedConnection.isDefault = connection.id == id
            return updatedConnection
        }
    }

    private func persist() {
        ConnectionStorage.saveConnections(connections, to: defaults)
        persistSelectedConnection()
    }

    private func persistSelectedConnection() {
        ConnectionStorage.saveSelectedConnectionID(selectedConnectionID, to: defaults)
    }
}

enum NetBoxConnectionSetup {
    static func validatedBaseURL(from urlString: String) throws -> URL {
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedURL.isEmpty else {
            throw APIError.invalidURL
        }

        let normalizedURLString: String
        if trimmedURL.contains("://") {
            normalizedURLString = trimmedURL
        } else {
            normalizedURLString = "https://\(trimmedURL)"
        }

        guard
            var components = URLComponents(string: normalizedURLString),
            let scheme = components.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            let host = components.host,
            !host.isEmpty
        else {
            throw APIError.invalidURL
        }

        components.scheme = scheme
        components.query = nil
        components.fragment = nil

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        return url
    }

    static func defaultName(for url: URL) -> String {
        url.host ?? "NetBox"
    }
}
