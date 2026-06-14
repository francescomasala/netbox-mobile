import Foundation
import Observation

@MainActor
@Observable
final class SearchViewModel {
    enum Section: String, CaseIterable, Identifiable {
        case devices = "Devices"
        case prefixes = "Prefixes"
        case ipAddresses = "IP Addresses"
        var id: String { rawValue }
    }

    struct Results {
        var devices: [Device] = []
        var prefixes: [Prefix] = []
        var ipAddresses: [IPAddress] = []

        var isEmpty: Bool {
            devices.isEmpty && prefixes.isEmpty && ipAddresses.isEmpty
        }
    }

    var query: String = ""
    var results: Results = Results()
    var isLoading = false
    var error: APIError?
    var isShowingCachedResults = false
    var cachedDate: Date?

    @ObservationIgnored let dcimRepository: any DCIMRepositoryProtocol
    @ObservationIgnored let ipamRepository: any IPAMRepositoryProtocol
    @ObservationIgnored let cache: OfflineCacheStore?
    @ObservationIgnored private var searchTask: Task<Void, Never>?

    init(
        dcimRepository: any DCIMRepositoryProtocol,
        ipamRepository: any IPAMRepositoryProtocol,
        cache: OfflineCacheStore?
    ) {
        self.dcimRepository = dcimRepository
        self.ipamRepository = ipamRepository
        self.cache = cache
    }

    func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await search()
        }
    }

    func search() async {
        let currentQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard currentQuery.count >= 2 else {
            results = Results()
            error = nil
            isShowingCachedResults = false
            cachedDate = nil
            return
        }

        if let cached = cache?.cachedSearchResults(for: currentQuery) {
            results = Results(
                devices: cached.devices,
                prefixes: cached.prefixes,
                ipAddresses: cached.ipAddresses
            )
            cachedDate = cached.savedAt
            isShowingCachedResults = true
        }

        isLoading = results.isEmpty
        error = nil

        let dcim = dcimRepository
        let ipam = ipamRepository

        do {
            async let deviceResult = dcim.fetchDevices(
                siteId: nil, status: nil, query: currentQuery, assetTag: nil
            )
            async let prefixResult = ipam.fetchPrefixes(
                vrfId: nil, family: nil, query: currentQuery
            )
            async let ipResult = ipam.fetchIPAddresses(
                prefixId: nil, query: currentQuery
            )

            let (dr, pr, ir) = try await (deviceResult, prefixResult, ipResult)

            results = Results(
                devices: dr.items,
                prefixes: pr.items,
                ipAddresses: ir
            )
            isShowingCachedResults = false
            cachedDate = nil

            cache?.saveSearchResults(
                CachedSearchResults(
                    devices: dr.items,
                    prefixes: pr.items,
                    ipAddresses: ir,
                    savedAt: Date()
                ),
                for: currentQuery
            )
        } catch is CancellationError {
        } catch let apiError as APIError {
            error = apiError
        } catch {
            self.error = .networkUnavailable
        }

        isLoading = false
    }

    func clear() {
        searchTask?.cancel()
        query = ""
        results = Results()
        error = nil
        isShowingCachedResults = false
        cachedDate = nil
    }
}
