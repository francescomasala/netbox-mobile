import Foundation
import Observation

@MainActor
@Observable
final class DeviceListViewModel {
    var devices: [Device] = []
    var isLoading = false
    var error: APIError?
    var selectedStatus: String? = nil
    var selectedSiteId: Int? = nil
    var searchText: String = ""
    var totalCount: Int = 0

    var isTruncated: Bool { totalCount > devices.count }

    var filteredDevices: [Device] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return devices }
        return devices.filter { device in
            device.name?.lowercased().contains(query) == true
                || device.display.lowercased().contains(query)
                || device.assetTag?.lowercased().contains(query) == true
                || device.serial.lowercased().contains(query)
        }
    }

    @ObservationIgnored let repository: any DCIMRepositoryProtocol

    init(repository: any DCIMRepositoryProtocol) {
        self.repository = repository
    }

    func load() async {
        isLoading = true
        error = nil

        do {
            let result = try await repository.fetchDevices(
                siteId: selectedSiteId,
                status: selectedStatus,
                query: nil,
                assetTag: nil
            )
            devices = result.items
            totalCount = result.totalCount
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
