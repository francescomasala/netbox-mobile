import Foundation
import Observation

@MainActor
@Observable
final class CircuitsListViewModel {
    enum Mode: String, CaseIterable, Identifiable {
        case physical = "Circuits"
        case virtual = "Virtual"

        var id: String { rawValue }
    }

    var circuits: [Circuit] = []
    var virtualCircuits: [VirtualCircuit] = []
    var selectedMode: Mode = .physical
    var searchText = ""
    var isLoading = false
    var error: APIError?
    var physicalTotalCount = 0
    var virtualTotalCount = 0

    var isTruncated: Bool {
        switch selectedMode {
        case .physical:
            physicalTotalCount > circuits.count
        case .virtual:
            virtualTotalCount > virtualCircuits.count
        }
    }

    var totalCount: Int {
        switch selectedMode {
        case .physical:
            physicalTotalCount
        case .virtual:
            virtualTotalCount
        }
    }

    var filteredCircuits: [Circuit] {
        let query = normalizedSearchText
        guard !query.isEmpty else { return circuits }
        return circuits.filter { circuit in
            circuit.cid.lowercased().contains(query)
                || circuit.display.lowercased().contains(query)
                || circuit.provider.name.lowercased().contains(query)
                || circuit.circuitType.name.lowercased().contains(query)
                || circuit.description.lowercased().contains(query)
        }
    }

    var filteredVirtualCircuits: [VirtualCircuit] {
        let query = normalizedSearchText
        guard !query.isEmpty else { return virtualCircuits }
        return virtualCircuits.filter { circuit in
            circuit.cid.lowercased().contains(query)
                || circuit.display.lowercased().contains(query)
                || circuit.providerNetwork?.name.lowercased().contains(query) == true
                || circuit.circuitType.name.lowercased().contains(query)
                || circuit.description.lowercased().contains(query)
        }
    }

    @ObservationIgnored let repository: any CircuitsRepositoryProtocol
    @ObservationIgnored let cache: OfflineCacheStore?

    init(repository: any CircuitsRepositoryProtocol, cache: OfflineCacheStore?) {
        self.repository = repository
        self.cache = cache
    }

    func load() async {
        isLoading = true
        error = nil

        do {
            switch selectedMode {
            case .physical:
                let result = try await repository.fetchCircuits(query: nil)
                circuits = result.items
                physicalTotalCount = result.totalCount
            case .virtual:
                let result = try await repository.fetchVirtualCircuits(query: nil)
                virtualCircuits = result.items
                virtualTotalCount = result.totalCount
            }
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

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
