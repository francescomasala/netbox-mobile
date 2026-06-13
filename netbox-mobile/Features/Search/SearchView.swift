import SwiftUI

struct SearchView: View {
    @State private var viewModel: SearchViewModel

    init(dcimRepository: any DCIMRepositoryProtocol, ipamRepository: any IPAMRepositoryProtocol) {
        _viewModel = State(initialValue: SearchViewModel(
            dcimRepository: dcimRepository,
            ipamRepository: ipamRepository
        ))
    }

    var body: some View {
        content
            .navigationTitle("Search")
            .searchable(text: $viewModel.query, prompt: "Devices, prefixes, IPs…")
            .onChange(of: viewModel.query) {
                viewModel.scheduleSearch()
            }
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        ScannerView(repository: viewModel.dcimRepository)
                    } label: {
                        Label("Scan", systemImage: "camera")
                    }
                }
#endif
            }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.query.count < 2 {
            ContentUnavailableView(
                "Search NetBox",
                systemImage: "magnifyingglass",
                description: Text("Type at least 2 characters to search devices, prefixes, and IP addresses.")
            )
        } else if let error = viewModel.error {
            ErrorView(error: error) {
                Task { await viewModel.search() }
            }
        } else if viewModel.results.isEmpty {
            ContentUnavailableView(
                "No Results",
                systemImage: "magnifyingglass",
                description: Text("No matches for \"\(viewModel.query)\". Try a different search term.")
            )
        } else {
            List {
                ForEach(SearchViewModel.Section.allCases) { section in
                    resultsSection(section)
                }
            }
        }
    }

    @ViewBuilder
    private func resultsSection(_ section: SearchViewModel.Section) -> some View {
        switch section {
        case .devices:
            if !viewModel.results.devices.isEmpty {
                Section("\(section.rawValue) (\(viewModel.results.devices.count))") {
                    ForEach(viewModel.results.devices) { device in
                        NavigationLink {
                            DeviceDetailView(
                                device: device,
                                repository: viewModel.dcimRepository
                            )
                        } label: {
                            SearchDeviceRow(device: device)
                        }
                    }
                }
            }
        case .prefixes:
            if !viewModel.results.prefixes.isEmpty {
                Section("\(section.rawValue) (\(viewModel.results.prefixes.count))") {
                    ForEach(viewModel.results.prefixes) { prefix in
                        NavigationLink {
                            PrefixDetailView(
                                prefix: prefix,
                                repository: viewModel.ipamRepository
                            )
                        } label: {
                            SearchPrefixRow(prefix: prefix)
                        }
                    }
                }
            }
        case .ipAddresses:
            if !viewModel.results.ipAddresses.isEmpty {
                Section("\(section.rawValue) (\(viewModel.results.ipAddresses.count))") {
                    ForEach(viewModel.results.ipAddresses) { ip in
                        SearchIPRow(ip: ip)
                    }
                }
            }
        }
    }
}

// MARK: - Search result rows

private struct SearchDeviceRow: View {
    let device: Device

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "server.rack")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.netBoxStatus(device.status.value))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.netBoxStatus(device.status.value).opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name ?? device.display)
                    .font(.subheadline.weight(.semibold))
                Text((device.site?.name ?? "—") + " · " + device.deviceType.model)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SearchPrefixRow: View {
    let prefix: Prefix

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: prefix.family.value == 6 ? "network" : "rectangle.3.group")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(prefix.family.value == 6 ? Color.purple : Color.blue)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill((prefix.family.value == 6 ? Color.purple : Color.blue).opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(prefix.prefix)
                    .font(.subheadline.weight(.semibold).monospaced())
                if !prefix.description.isEmpty {
                    Text(prefix.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct SearchIPRow: View {
    let ip: IPAddress

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "number")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.netBoxStatus(ip.status.value))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.netBoxStatus(ip.status.value).opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(ip.address)
                    .font(.subheadline.weight(.semibold).monospaced())
                if !ip.dnsName.isEmpty {
                    Text(ip.dnsName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
