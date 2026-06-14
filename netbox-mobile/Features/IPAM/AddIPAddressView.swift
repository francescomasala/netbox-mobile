import SwiftUI

struct AddIPAddressView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: AddIPAddressViewModel

    let prefix: Prefix?
    let onCreated: (IPAddress) -> Void

    init(
        prefix: Prefix?,
        ipamRepository: any IPAMRepositoryProtocol,
        dcimRepository: (any DCIMRepositoryProtocol)?,
        onCreated: @escaping (IPAddress) -> Void
    ) {
        self.prefix = prefix
        self.onCreated = onCreated
        _viewModel = State(initialValue: AddIPAddressViewModel(
            ipamRepository: ipamRepository,
            dcimRepository: dcimRepository
        ))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Address") {
                    TextField(addressPlaceholder, text: $viewModel.address)
#if os(iOS)
                        .keyboardType(.numbersAndPunctuation)
#endif

                    Picker("Status", selection: $viewModel.selectedStatus) {
                        ForEach(IPAddressStatusOption.all) { option in
                            Text(option.label).tag(option.value)
                        }
                    }

                    TextField("DNS Name", text: $viewModel.dnsName)
                        .autocorrectionDisabled()

                    TextField("Description", text: $viewModel.description, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Assignment") {
                    Picker("Assignment", selection: $viewModel.assignmentMode) {
                        ForEach(AddIPAddressViewModel.AssignmentMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if viewModel.assignmentMode == .interface {
                        deviceSearch
                        deviceResults
                        interfacePicker
                    }
                }

                if let validationMessage = viewModel.validationMessage {
                    Section {
                        Label(validationMessage, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                if let error = viewModel.error {
                    Section {
                        Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add IP Address")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Label("Save", systemImage: "checkmark")
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
        }
    }

    private var deviceSearch: some View {
        HStack {
            TextField("Device", text: $viewModel.deviceQuery)
                .autocorrectionDisabled()
                .onSubmit {
                    Task { await viewModel.searchDevices() }
                }

            Button {
                Task { await viewModel.searchDevices() }
            } label: {
                if viewModel.isSearchingDevices {
                    ProgressView()
                } else {
                    Image(systemName: "magnifyingglass")
                }
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.isSearchingDevices)
        }
    }

    @ViewBuilder
    private var deviceResults: some View {
        let devices: [Device] = viewModel.deviceResults
        if !devices.isEmpty {
            ForEach(devices, id: \.id) { (device: Device) in
                Button {
                    Task { await viewModel.selectDevice(device) }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.name ?? device.display)
                                .foregroundStyle(.primary)
                            Text(device.site?.name ?? "—")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if viewModel.selectedDevice?.id == device.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var interfacePicker: some View {
        if viewModel.isLoadingInterfaces {
            ProgressView("Loading interfaces")
        } else if !viewModel.interfaces.isEmpty {
            Picker("Interface", selection: $viewModel.selectedInterfaceId) {
                ForEach(viewModel.interfaces) { iface in
                    Text(iface.name).tag(Optional(iface.id))
                }
            }
        } else if viewModel.selectedDevice != nil {
            Label("No interfaces", systemImage: "cable.connector.slash")
                .foregroundStyle(.secondary)
        }
    }

    private var addressPlaceholder: String {
        prefix?.prefix ?? "192.0.2.10/24"
    }

    private func save() async {
        guard let ipAddress = await viewModel.save() else { return }
        onCreated(ipAddress)
        dismiss()
    }
}
