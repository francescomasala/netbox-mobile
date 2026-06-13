import Foundation
import Testing
@testable import netbox_mobile

struct KeychainWrapperTests {
    @Test func savesLoadsUpdatesAndDeletesToken() async throws {
        let keychain = KeychainWrapper(service: "it.hyperbit.netboxmobile.tests.\(UUID().uuidString)")
        let connectionID = UUID()

        try await keychain.save(token: "first-token", for: connectionID)
        let firstToken = try await keychain.load(for: connectionID)
        #expect(firstToken == "first-token")

        try await keychain.save(token: "rotated-token", for: connectionID)
        let rotatedToken = try await keychain.load(for: connectionID)
        #expect(rotatedToken == "rotated-token")

        try await keychain.delete(for: connectionID)

        do {
            _ = try await keychain.load(for: connectionID)
            #expect(Bool(false), "Expected missing Keychain item to throw")
        } catch KeychainError.itemNotFound {
            #expect(true)
        } catch {
            #expect(Bool(false), "Unexpected Keychain error: \(error)")
        }
    }

    @Test func connectionStoragePersistsConnectionsAndSelection() throws {
        let suiteName = "it.hyperbit.netboxmobile.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let connection = Connection(
            id: UUID(),
            name: "HyperBit Prod",
            baseURL: try #require(URL(string: "https://netbox.hyperbit.it")),
            isDefault: true,
            allowSelfSignedCertificates: true
        )

        ConnectionStorage.saveConnections([connection], to: defaults)
        ConnectionStorage.saveSelectedConnectionID(connection.id, to: defaults)

        let loadedConnections = ConnectionStorage.loadConnections(from: defaults)
        let selectedID = ConnectionStorage.loadSelectedConnectionID(from: defaults)

        #expect(loadedConnections == [connection])
        #expect(selectedID == connection.id)
    }

    @Test func setupBuildsURLFromBareDomain() throws {
        let url = try NetBoxConnectionSetup.validatedBaseURL(from: "netbox.hyperbit.it")

        #expect(url.absoluteString == "https://netbox.hyperbit.it")
        #expect(NetBoxConnectionSetup.defaultName(for: url) == "netbox.hyperbit.it")
    }

    @Test func setupBuildsURLWithCustomPortAndScheme() throws {
        let url = try NetBoxConnectionSetup.validatedBaseURL(
            from: "http://netbox.hyperbit.it:8080/netbox"
        )

        #expect(url.absoluteString == "http://netbox.hyperbit.it:8080/netbox")
    }

    @Test func setupRejectsEmptyURL() throws {
        do {
            _ = try NetBoxConnectionSetup.validatedBaseURL(from: "")
            #expect(Bool(false), "Expected empty URL to throw")
        } catch APIError.invalidURL {
            #expect(true)
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }

    @MainActor
    @Test func setupIsRequiredWhenConnectionOrTokenIsMissing() async throws {
        let suiteName = "it.hyperbit.netboxmobile.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let keychain = KeychainWrapper(service: "it.hyperbit.netboxmobile.tests.\(UUID().uuidString)")
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let emptyViewModel = ConnectionsViewModel(keychain: keychain, defaults: defaults)
        let emptySetupRequired = await emptyViewModel.setupIsRequired()
        #expect(emptySetupRequired)

        let connection = Connection(
            id: UUID(),
            name: "HyperBit Prod",
            baseURL: try #require(URL(string: "https://netbox.hyperbit.it:443")),
            isDefault: true
        )
        ConnectionStorage.saveConnections([connection], to: defaults)
        ConnectionStorage.saveSelectedConnectionID(connection.id, to: defaults)

        let missingTokenViewModel = ConnectionsViewModel(keychain: keychain, defaults: defaults)
        let missingTokenSetupRequired = await missingTokenViewModel.setupIsRequired()
        #expect(missingTokenSetupRequired)

        try await keychain.save(token: "test-token", for: connection.id)

        let validViewModel = ConnectionsViewModel(keychain: keychain, defaults: defaults)
        let validSetupRequired = await validViewModel.setupIsRequired()
        #expect(!validSetupRequired)

        try await keychain.delete(for: connection.id)
    }
}
