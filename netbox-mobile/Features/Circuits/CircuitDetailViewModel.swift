import Foundation
import Observation

@MainActor
@Observable
final class CircuitDetailViewModel {
    var circuit: Circuit
    var terminations: [CircuitTermination] = []
    var isLoading = false
    var error: APIError?
    var isShowingCachedData = false
    var cachedDate: Date?

    @ObservationIgnored private let repository: any CircuitsRepositoryProtocol
    @ObservationIgnored private let cache: OfflineCacheStore?

    init(circuit: Circuit, repository: any CircuitsRepositoryProtocol, cache: OfflineCacheStore?) {
        self.circuit = circuit
        self.repository = repository
        self.cache = cache
    }

    func load() async {
        if let cached = cache?.cachedCircuitDetail(id: circuit.id), terminations.isEmpty {
            circuit = cached.circuit
            terminations = cached.terminations
            cachedDate = cached.savedAt
            isShowingCachedData = true
        }

        isLoading = true
        error = nil

        do {
            async let refreshedCircuit = repository.fetchCircuit(id: circuit.id)
            async let refreshedTerminations = repository.fetchCircuitTerminations(circuitId: circuit.id)
            let (loadedCircuit, loadedTerminations) = try await (refreshedCircuit, refreshedTerminations)
            circuit = loadedCircuit
            terminations = loadedTerminations
            isShowingCachedData = false
            cachedDate = nil
            cache?.saveCircuitDetail(circuit: loadedCircuit, terminations: loadedTerminations)
        } catch is CancellationError {
        } catch let apiError as APIError {
            error = apiError
        } catch {
            self.error = .networkUnavailable
        }

        isLoading = false
    }
}

@MainActor
@Observable
final class VirtualCircuitDetailViewModel {
    var circuit: VirtualCircuit
    var terminations: [VirtualCircuitTermination] = []
    var isLoading = false
    var error: APIError?
    var isShowingCachedData = false
    var cachedDate: Date?

    @ObservationIgnored private let repository: any CircuitsRepositoryProtocol
    @ObservationIgnored private let cache: OfflineCacheStore?

    init(circuit: VirtualCircuit, repository: any CircuitsRepositoryProtocol, cache: OfflineCacheStore?) {
        self.circuit = circuit
        self.repository = repository
        self.cache = cache
    }

    func load() async {
        if let cached = cache?.cachedVirtualCircuitDetail(id: circuit.id), terminations.isEmpty {
            circuit = cached.circuit
            terminations = cached.terminations
            cachedDate = cached.savedAt
            isShowingCachedData = true
        }

        isLoading = true
        error = nil

        do {
            async let refreshedCircuit = repository.fetchVirtualCircuit(id: circuit.id)
            async let refreshedTerminations = repository.fetchVirtualCircuitTerminations(virtualCircuitId: circuit.id)
            let (loadedCircuit, loadedTerminations) = try await (refreshedCircuit, refreshedTerminations)
            circuit = loadedCircuit
            terminations = loadedTerminations
            isShowingCachedData = false
            cachedDate = nil
            cache?.saveVirtualCircuitDetail(circuit: loadedCircuit, terminations: loadedTerminations)
        } catch is CancellationError {
        } catch let apiError as APIError {
            error = apiError
        } catch {
            self.error = .networkUnavailable
        }

        isLoading = false
    }
}
