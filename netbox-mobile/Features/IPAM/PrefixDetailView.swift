import SwiftUI

struct PrefixDetailView: View {
    @State private var viewModel: PrefixDetailViewModel

    init(prefix: Prefix, repository: any IPAMRepositoryProtocol) {
        _viewModel = State(initialValue: PrefixDetailViewModel(prefix: prefix, repository: repository))
    }

    var body: some View {
        List {
            Section {
                PrefixHeader(prefix: viewModel.prefix)
            }

            Section("Details") {
                LabeledContent("VRF", value: viewModel.prefix.vrf?.name ?? "Global")
                if !viewModel.prefix.description.isEmpty {
                    LabeledContent("Description", value: viewModel.prefix.description)
                }
                if viewModel.prefix.isPool {
                    LabeledContent("Type", value: "Address Pool")
                }
                if let utilization = viewModel.prefix.utilization {
                    LabeledContent("Utilization") {
                        UtilizationMeter(value: utilization)
                    }
                }
            }

            Section("IP Addresses") {
                if viewModel.isLoading && viewModel.ipAddresses.isEmpty {
                    ProgressView()
                } else if let error = viewModel.error {
                    ErrorView(error: error) {
                        Task { await viewModel.load() }
                    }
                } else if viewModel.ipAddresses.isEmpty {
                    ContentUnavailableView("No IP Addresses", systemImage: "tray")
                } else {
                    ForEach(viewModel.ipAddresses) { ipAddress in
                        IPAddressRow(ipAddress: ipAddress)
                    }
                }
            }
        }
        .navigationTitle(viewModel.prefix.prefix)
        .task {
            if viewModel.ipAddresses.isEmpty {
                await viewModel.load()
            }
        }
        .refreshable {
            await viewModel.load()
        }
    }
}

private struct PrefixHeader: View {
    let prefix: Prefix

    private var iconColor: Color {
        prefix.family.value == 6 ? .purple : .blue
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: prefix.family.value == 6 ? "network" : "rectangle.3.group")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(iconColor.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(prefix.prefix)
                    .font(.title2.monospaced().weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                HStack(spacing: 6) {
                    StatusBadge(status: prefix.status)
                    AddressFamilyBadge(family: prefix.family)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

private struct IPAddressRow: View {
    let ipAddress: IPAddress

    private var statusColor: Color {
        Color.netBoxStatus(ipAddress.status.value)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "number")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(statusColor)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(statusColor.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(ipAddress.address)
                        .font(.body.monospaced().weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Spacer(minLength: 8)

                    StatusBadge(status: ipAddress.status)
                }

                if !ipAddress.dnsName.isEmpty {
                    Label(ipAddress.dnsName, systemImage: "globe")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let assignedObject = ipAddress.assignedObject {
                    Label(assignedObject.display, systemImage: "link")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !ipAddress.description.isEmpty {
                    Text(ipAddress.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 6)
    }
}
