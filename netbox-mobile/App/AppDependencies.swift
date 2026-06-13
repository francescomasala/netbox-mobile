import Foundation
import Observation
import SwiftUI

@Observable
final class AppDependencies {
    let baseURL: URL
    let client: NetBoxClient
    let ipamRepository: any IPAMRepositoryProtocol
    let dcimRepository: any DCIMRepositoryProtocol

    init(connection: Connection, keychain: KeychainWrapper) {
        self.baseURL = connection.baseURL
        let client = NetBoxClient(connection: connection, keychain: keychain)
        self.client = client
        self.ipamRepository = IPAMRepository(client: client)
        self.dcimRepository = DCIMRepository(client: client)
    }
}

extension EnvironmentValues {
    @Entry var appDependencies: AppDependencies? = nil
}
