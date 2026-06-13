import Foundation
import Observation

@MainActor
@Observable
final class PrefixListViewModel {
    var prefixes: [Prefix] = []
    var isLoading = false
    var error: APIError?
    var selectedFamily: Int?

    @ObservationIgnored let repository: any IPAMRepositoryProtocol

    init(repository: any IPAMRepositoryProtocol) {
        self.repository = repository
    }

    func load() async {
        isLoading = true
        error = nil

        do {
            prefixes = try await repository.fetchPrefixes(vrfId: nil, family: selectedFamily)
        } catch is CancellationError {
        } catch let apiError as APIError {
            error = apiError
        } catch {
            self.error = .networkUnavailable
        }

        isLoading = false
    }

    func refresh() async {
        await load()
    }
}
