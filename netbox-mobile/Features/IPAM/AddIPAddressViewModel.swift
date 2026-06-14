import Foundation
import Observation

struct IPAddressStatusOption: Identifiable, Hashable {
    let value: String
    let label: String

    var id: String { value }

    static let all: [IPAddressStatusOption] = [
        IPAddressStatusOption(value: "active", label: "Active"),
        IPAddressStatusOption(value: "reserved", label: "Reserved"),
        IPAddressStatusOption(value: "deprecated", label: "Deprecated"),
        IPAddressStatusOption(value: "dhcp", label: "DHCP"),
        IPAddressStatusOption(value: "slaac", label: "SLAAC")
    ]
}

@MainActor
@Observable
final class AddIPAddressViewModel {
    enum AssignmentMode: String, CaseIterable, Identifiable {
        case unassigned = "Unassigned"
        case interface = "Device Interface"

        var id: String { rawValue }
    }

    var address = ""
    var selectedStatus = "active"
    var dnsName = ""
    var description = ""
    var assignmentMode: AssignmentMode = .unassigned
    var deviceQuery = ""
    var deviceResults: [Device] = []
    var selectedDevice: Device?
    var interfaces: [Interface] = []
    var selectedInterfaceId: Int?
    var isSearchingDevices = false
    var isLoadingInterfaces = false
    var isSaving = false
    var validationMessage: String?
    var error: APIError?

    @ObservationIgnored private let ipamRepository: any IPAMRepositoryProtocol
    @ObservationIgnored private let dcimRepository: (any DCIMRepositoryProtocol)?

    init(ipamRepository: any IPAMRepositoryProtocol, dcimRepository: (any DCIMRepositoryProtocol)?) {
        self.ipamRepository = ipamRepository
        self.dcimRepository = dcimRepository
    }

    func searchDevices() async {
        let query = deviceQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            deviceResults = []
            return
        }
        guard let dcimRepository else {
            validationMessage = "Device assignment is unavailable for this connection."
            return
        }

        isSearchingDevices = true
        validationMessage = nil
        error = nil

        do {
            let result = try await dcimRepository.fetchDevices(
                siteId: nil,
                status: nil,
                query: query,
                assetTag: nil
            )
            deviceResults = Array(result.items.prefix(20))
        } catch is CancellationError {
        } catch let apiError as APIError {
            error = apiError
        } catch {
            self.error = .networkUnavailable
        }

        isSearchingDevices = false
    }

    func selectDevice(_ device: Device) async {
        selectedDevice = device
        selectedInterfaceId = nil
        interfaces = []
        await loadInterfaces(for: device)
    }

    func save() async -> IPAddress? {
        validationMessage = nil
        error = nil

        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty else {
            validationMessage = "Enter an IP address with prefix length."
            return nil
        }

        let assignment = assignmentPayload()
        if assignmentMode == .interface && assignment == nil {
            validationMessage = "Select a device interface or switch assignment to Unassigned."
            return nil
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let request = CreateIPAddressRequest(
                address: trimmedAddress,
                status: selectedStatus,
                dnsName: cleanedOptional(dnsName),
                description: cleanedOptional(description),
                assignedObjectType: assignment?.type,
                assignedObjectId: assignment?.id
            )
            return try await ipamRepository.createIPAddress(request)
        } catch is CancellationError {
            return nil
        } catch let apiError as APIError {
            error = apiError
        } catch {
            self.error = .networkUnavailable
        }

        return nil
    }

    private func loadInterfaces(for device: Device) async {
        guard let dcimRepository else { return }
        isLoadingInterfaces = true
        validationMessage = nil
        error = nil

        do {
            interfaces = try await dcimRepository.fetchInterfaces(deviceId: device.id)
            selectedInterfaceId = interfaces.first?.id
        } catch is CancellationError {
        } catch let apiError as APIError {
            error = apiError
        } catch {
            self.error = .networkUnavailable
        }

        isLoadingInterfaces = false
    }

    private func assignmentPayload() -> (type: String, id: Int)? {
        guard assignmentMode == .interface, let selectedInterfaceId else { return nil }
        return ("dcim.interface", selectedInterfaceId)
    }

    private func cleanedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
