import SwiftUI

struct DeviceDetailView: View {
    @State private var viewModel: DeviceDetailViewModel
    @Environment(\.appDependencies) private var dependencies

    init(device: Device, repository: any DCIMRepositoryProtocol) {
        _viewModel = State(initialValue: DeviceDetailViewModel(device: device, repository: repository))
    }

    var body: some View {
        List {
            headerSection
            primaryIPSection
            interfacesSection
        }
        .navigationTitle(viewModel.device.name ?? viewModel.device.display)
        .toolbar {
            if let url = deviceShareURL {
                ToolbarItem {
                    ShareLink("Open in NetBox", item: url)
                }
            }
        }
        .task {
            if viewModel.interfaces.isEmpty {
                await viewModel.loadInterfaces()
            }
        }
        .refreshable {
            await viewModel.loadInterfaces()
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        Section {
            LabeledContent("Status") { StatusBadge(status: viewModel.device.status) }
            if let site = viewModel.device.site {
                LabeledContent("Site", value: site.name)
            }
            if let rack = viewModel.device.rack {
                LabeledContent("Rack", value: rack.display)
            }
            if let position = viewModel.device.position {
                LabeledContent("Position", value: "U\(position.formatted())")
            }
            LabeledContent("Type") {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(viewModel.device.deviceType.model)
                    Text(viewModel.device.deviceType.manufacturer.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if !viewModel.device.serial.isEmpty {
                LabeledContent("Serial", value: viewModel.device.serial)
            }
            if let assetTag = viewModel.device.assetTag {
                LabeledContent("Asset Tag", value: assetTag)
            }
            if !viewModel.device.description.isEmpty {
                LabeledContent("Description", value: viewModel.device.description)
            }
            if !viewModel.device.comments.isEmpty {
                LabeledContent("Comments", value: viewModel.device.comments)
            }
        } header: {
            Text("Device")
        }
    }

    @ViewBuilder
    private var primaryIPSection: some View {
        let hasIP = viewModel.device.primaryIp4 != nil || viewModel.device.primaryIp6 != nil
        if hasIP {
            Section("Primary IP") {
                if let ip4 = viewModel.device.primaryIp4 {
                    IPCopyRow(address: ip4.address)
                }
                if let ip6 = viewModel.device.primaryIp6 {
                    IPCopyRow(address: ip6.address)
                }
            }
        }
    }

    private var interfacesSection: some View {
        Section("Interfaces") {
            if viewModel.isLoadingInterfaces && viewModel.interfaces.isEmpty {
                ProgressView()
            } else if let error = viewModel.error {
                ErrorView(error: error) {
                    Task { await viewModel.loadInterfaces() }
                }
            } else if viewModel.interfaces.isEmpty {
                ContentUnavailableView("No Interfaces", systemImage: "cable.connector")
            } else {
                ForEach(viewModel.interfaces) { iface in
                    InterfaceRow(iface: iface)
                }
            }
        }
    }

    // MARK: - Helpers

    private var deviceShareURL: URL? {
        guard let base = dependencies?.baseURL else { return nil }
        return base
            .appendingPathComponent("dcim")
            .appendingPathComponent("devices")
            .appendingPathComponent("\(viewModel.device.id)")
    }
}

// MARK: - Sub-views

private struct IPCopyRow: View {
    let address: String
    @State private var copied = false

    var body: some View {
        Button {
            copyAddress()
        } label: {
            HStack {
                Text(address)
                    .font(.body.monospaced())
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func copyAddress() {
#if os(iOS)
        UIPasteboard.general.string = address
#else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(address, forType: .string)
#endif
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
    }
}

private struct InterfaceRow: View {
    let iface: Interface

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(iface.enabled ? Color.green : Color.red)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(iface.name)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if iface.countIpaddresses > 0 {
                        Text("\(iface.countIpaddresses) IP")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Text(iface.interfaceType.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let mtu = iface.mtu {
                    Text("MTU \(mtu)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
