import Foundation
import Observation

struct DeviceStatusOption: Identifiable, Hashable {
    let value: String
    let label: String

    var id: String { value }

    static let all: [DeviceStatusOption] = [
        DeviceStatusOption(value: "active", label: "Active"),
        DeviceStatusOption(value: "planned", label: "Planned"),
        DeviceStatusOption(value: "staged", label: "Staged"),
        DeviceStatusOption(value: "failed", label: "Failed"),
        DeviceStatusOption(value: "offline", label: "Offline"),
        DeviceStatusOption(value: "decommissioning", label: "Decommissioning")
    ]
}

@MainActor
@Observable
final class DeviceDetailViewModel {
    var device: Device
    var interfaces: [Interface] = []
    var isLoadingInterfaces = false
    var isUpdatingStatus = false
    var error: APIError?
    var mutationError: APIError?
    var isShowingCachedData = false
    var cachedDate: Date?

    @ObservationIgnored private let repository: any DCIMRepositoryProtocol
    @ObservationIgnored private let cache: OfflineCacheStore?

    init(device: Device, repository: any DCIMRepositoryProtocol, cache: OfflineCacheStore?) {
        self.device = device
        self.repository = repository
        self.cache = cache
    }

    func loadInterfaces() async {
        if let cached = cache?.cachedDeviceDetail(id: device.id), interfaces.isEmpty {
            device = cached.device
            interfaces = cached.interfaces
            cachedDate = cached.savedAt
            isShowingCachedData = true
        }

        isLoadingInterfaces = true
        error = nil

        do {
            async let refreshedDevice = repository.fetchDevice(id: device.id)
            async let refreshedInterfaces = repository.fetchInterfaces(deviceId: device.id)
            let (loadedDevice, loadedInterfaces) = try await (refreshedDevice, refreshedInterfaces)
            device = loadedDevice
            interfaces = loadedInterfaces
            isShowingCachedData = false
            cachedDate = nil
            cache?.saveDeviceDetail(device: loadedDevice, interfaces: loadedInterfaces)
        } catch is CancellationError {
        } catch let apiError as APIError {
            error = apiError
        } catch {
            self.error = .networkUnavailable
        }

        isLoadingInterfaces = false
    }

    func updateStatus(to status: DeviceStatusOption) async {
        guard status.value != device.status.value else { return }
        isUpdatingStatus = true
        mutationError = nil

        do {
            device = try await repository.updateDeviceStatus(deviceId: device.id, status: status.value)
            cache?.saveDeviceDetail(device: device, interfaces: interfaces)
        } catch is CancellationError {
        } catch let apiError as APIError {
            mutationError = apiError
        } catch {
            mutationError = .networkUnavailable
        }

        isUpdatingStatus = false
    }
}
