#if os(iOS)
import Foundation
import Observation

@MainActor
@Observable
final class ScannerViewModel {
    enum ScanResult {
        case idle
        case scanning
        case found(Device)
        case notFound(tag: String)
        case error(APIError)
    }

    var result: ScanResult = .idle
    var isPaused: Bool = false

    @ObservationIgnored let repository: any DCIMRepositoryProtocol

    init(repository: any DCIMRepositoryProtocol) {
        self.repository = repository
    }

    func handleScannedCode(_ code: String) async {
        guard !isPaused else { return }
        isPaused = true
        result = .scanning

        do {
            let pagedResult = try await repository.fetchDevices(
                siteId: nil,
                status: nil,
                query: nil,
                assetTag: code
            )
            if let device = pagedResult.items.first {
                result = .found(device)
            } else {
                result = .notFound(tag: code)
            }
        } catch is CancellationError {
            isPaused = false
        } catch let apiError as APIError {
            result = .error(apiError)
        } catch {
            result = .error(.networkUnavailable)
        }
    }

    func reset() {
        result = .idle
        isPaused = false
    }
}
#endif
