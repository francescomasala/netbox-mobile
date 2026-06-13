import Foundation
import Observation

@MainActor
@Observable
final class DeviceDetailViewModel {
    var device: Device
    var interfaces: [Interface] = []
    var isLoadingInterfaces = false
    var error: APIError?

    @ObservationIgnored private let repository: any DCIMRepositoryProtocol

    init(device: Device, repository: any DCIMRepositoryProtocol) {
        self.device = device
        self.repository = repository
    }

    func loadInterfaces() async {
        isLoadingInterfaces = true
        error = nil

        do {
            interfaces = try await repository.fetchInterfaces(deviceId: device.id)
        } catch is CancellationError {
        } catch let apiError as APIError {
            error = apiError
        } catch {
            self.error = .networkUnavailable
        }

        isLoadingInterfaces = false
    }
}
