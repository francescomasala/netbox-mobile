import Foundation
import Observation

@MainActor
@Observable
final class PrefixDetailViewModel {
    let prefix: Prefix
    var ipAddresses: [IPAddress] = []
    var isLoading = false
    var error: APIError?
    var isShowingCachedData = false
    var cachedDate: Date?

    @ObservationIgnored let repository: any IPAMRepositoryProtocol
    @ObservationIgnored private let cache: OfflineCacheStore?

    init(prefix: Prefix, repository: any IPAMRepositoryProtocol, cache: OfflineCacheStore?) {
        self.prefix = prefix
        self.repository = repository
        self.cache = cache
    }

    func load() async {
        if let cached = cache?.cachedPrefixDetail(id: prefix.id), ipAddresses.isEmpty {
            ipAddresses = cached.ipAddresses
            cachedDate = cached.savedAt
            isShowingCachedData = true
        }

        isLoading = true
        error = nil

        do {
            ipAddresses = try await repository.fetchIPAddresses(prefixId: prefix.id, query: nil)
            isShowingCachedData = false
            cachedDate = nil
            cache?.savePrefixDetail(prefix: prefix, ipAddresses: ipAddresses)
        } catch is CancellationError {
        } catch let apiError as APIError {
            error = apiError
        } catch {
            self.error = .networkUnavailable
        }

        isLoading = false
    }

    func addCreatedIPAddress(_ ipAddress: IPAddress) {
        ipAddresses.insert(ipAddress, at: 0)
        cache?.savePrefixDetail(prefix: prefix, ipAddresses: ipAddresses)
    }
}
