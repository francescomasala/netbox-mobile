import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AppDependencies {
    let baseURL: URL
    let client: NetBoxClient
    let ipamRepository: any IPAMRepositoryProtocol
    let dcimRepository: any DCIMRepositoryProtocol
    let circuitsRepository: any CircuitsRepositoryProtocol
    let offlineCache: OfflineCacheStore

    init(connection: Connection, keychain: KeychainWrapper) {
        self.baseURL = connection.baseURL
        let client = NetBoxClient(connection: connection, keychain: keychain)
        self.client = client
        self.ipamRepository = IPAMRepository(client: client)
        self.dcimRepository = DCIMRepository(client: client)
        self.circuitsRepository = CircuitsRepository(client: client)
        self.offlineCache = OfflineCacheStore()
    }
}

extension EnvironmentValues {
    @Entry var appDependencies: AppDependencies? = nil
}
