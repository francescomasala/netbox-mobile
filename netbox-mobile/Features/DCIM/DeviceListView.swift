import SwiftUI

struct DeviceListView: View {
    @State private var viewModel: DeviceListViewModel

    init(repository: any DCIMRepositoryProtocol) {
        _viewModel = State(initialValue: DeviceListViewModel(repository: repository))
    }

    var body: some View {
        content
            .navigationTitle("Devices")
            .searchable(text: $viewModel.searchText)
            .toolbar {
                ToolbarItem {
                    Picker("Status", selection: statusSelection) {
                        Text("All").tag(Optional<String>.none)
                        Text("Active").tag(Optional("active"))
                        Text("Planned").tag(Optional("planned"))
                        Text("Staged").tag(Optional("staged"))
                        Text("Failed").tag(Optional("failed"))
                        Text("Decommissioning").tag(Optional("decommissioning"))
                    }
                    .pickerStyle(.menu)
                }
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        ScannerView(repository: viewModel.repository)
                    } label: {
                        Label("Scan", systemImage: "camera")
                    }
                }
#endif
            }
            .safeAreaInset(edge: .top) {
                if viewModel.isTruncated {
                    TruncationBanner(totalCount: viewModel.totalCount)
                }
            }
            .task {
                if viewModel.devices.isEmpty {
                    await viewModel.load()
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.devices.isEmpty {
            ProgressView()
        } else if let error = viewModel.error, viewModel.devices.isEmpty {
            ErrorView(error: error) {
                Task { await viewModel.load() }
            }
        } else if viewModel.filteredDevices.isEmpty {
            ContentUnavailableView("No Devices", systemImage: "server.rack")
        } else {
#if os(macOS)
            Table(viewModel.filteredDevices) {
                TableColumn("Name") { device in
                    NavigationLink {
                        DeviceDetailView(device: device, repository: viewModel.repository)
                    } label: {
                        Text(device.name ?? device.display)
                    }
                }
                TableColumn("Site") { device in
                    Text(device.site?.name ?? "—")
                }
                TableColumn("Type") { device in
                    Text(device.deviceType.model)
                }
                TableColumn("Status") { device in
                    StatusBadge(status: device.status)
                }
            }
#else
            List(viewModel.filteredDevices) { device in
                NavigationLink {
                    DeviceDetailView(device: device, repository: viewModel.repository)
                } label: {
                    DeviceRow(device: device)
                }
            }
#endif
        }
    }

    private var statusSelection: Binding<String?> {
        Binding {
            viewModel.selectedStatus
        } set: { status in
            viewModel.selectedStatus = status
            Task { await viewModel.load() }
        }
    }
}

private struct DeviceRow: View {
    let device: Device

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "server.rack")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.netBoxStatus(device.status.value))
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.netBoxStatus(device.status.value).opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(device.name ?? device.display)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    StatusBadge(status: device.status)
                }

                Label(device.site?.name ?? "—", systemImage: "building.2")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(device.deviceType.manufacturer.name + " " + device.deviceType.model)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}
