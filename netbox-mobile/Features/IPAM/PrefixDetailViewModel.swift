import Foundation
import Observation

@MainActor
@Observable
final class PrefixDetailViewModel {
    let prefix: Prefix
    var ipAddresses: [IPAddress] = []
    var isLoading = false
    var error: APIError?

    @ObservationIgnored private let repository: any IPAMRepositoryProtocol

    init(prefix: Prefix, repository: any IPAMRepositoryProtocol) {
        self.prefix = prefix
        self.repository = repository
    }

    func load() async {
        isLoading = true
        error = nil

        do {
            ipAddresses = try await repository.fetchIPAddresses(prefixId: prefix.id)
        } catch is CancellationError {
        } catch let apiError as APIError {
            error = apiError
        } catch {
            self.error = .networkUnavailable
        }

        isLoading = false
    }
}
