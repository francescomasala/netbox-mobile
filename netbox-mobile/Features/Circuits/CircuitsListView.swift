import SwiftUI

struct CircuitsListView: View {
    @State private var viewModel: CircuitsListViewModel

    init(repository: any CircuitsRepositoryProtocol, cache: OfflineCacheStore?) {
        _viewModel = State(initialValue: CircuitsListViewModel(repository: repository, cache: cache))
    }

    var body: some View {
        content
            .navigationTitle("Circuits")
            .searchable(text: $viewModel.searchText)
            .toolbar {
                ToolbarItem {
                    Picker("Circuit Mode", selection: modeSelection) {
                        ForEach(CircuitsListViewModel.Mode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 260)
                }
            }
            .safeAreaInset(edge: .top) {
                if viewModel.isTruncated {
                    TruncationBanner(totalCount: viewModel.totalCount)
                }
            }
            .task {
                if currentItemsAreEmpty {
                    await viewModel.load()
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && currentItemsAreEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.error, currentItemsAreEmpty {
            ErrorView(error: error) {
                Task { await viewModel.load() }
            }
        } else {
            switch viewModel.selectedMode {
            case .physical:
                physicalList
            case .virtual:
                virtualList
            }
        }
    }

    @ViewBuilder
    private var physicalList: some View {
        if viewModel.filteredCircuits.isEmpty {
            EmptyStateView(
                title: "No Circuits",
                systemImage: "point.3.connected.trianglepath.dotted",
                message: "No physical circuits match the current filters."
            )
        } else {
            List(viewModel.filteredCircuits) { circuit in
                NavigationLink {
                    CircuitDetailView(
                        circuit: circuit,
                        repository: viewModel.repository,
                        cache: viewModel.cache
                    )
                } label: {
                    CircuitRow(circuit: circuit)
                }
            }
        }
    }

    @ViewBuilder
    private var virtualList: some View {
        if viewModel.filteredVirtualCircuits.isEmpty {
            EmptyStateView(
                title: "No Virtual Circuits",
                systemImage: "point.3.filled.connected.trianglepath.dotted",
                message: "No virtual circuits match the current filters."
            )
        } else {
            List(viewModel.filteredVirtualCircuits) { circuit in
                NavigationLink {
                    VirtualCircuitDetailView(
                        circuit: circuit,
                        repository: viewModel.repository,
                        cache: viewModel.cache
                    )
                } label: {
                    VirtualCircuitRow(circuit: circuit)
                }
            }
        }
    }

    private var modeSelection: Binding<CircuitsListViewModel.Mode> {
        Binding {
            viewModel.selectedMode
        } set: { mode in
            viewModel.selectedMode = mode
            if currentItemsAreEmpty {
                Task { await viewModel.load() }
            }
        }
    }

    private var currentItemsAreEmpty: Bool {
        switch viewModel.selectedMode {
        case .physical:
            viewModel.circuits.isEmpty
        case .virtual:
            viewModel.virtualCircuits.isEmpty
        }
    }
}

private struct CircuitRow: View {
    let circuit: Circuit

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            circuitIcon(status: circuit.status.value)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(circuit.cid.isEmpty ? circuit.display : circuit.cid)
                        .font(.headline.monospaced())
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Spacer(minLength: 8)

                    StatusBadge(status: circuit.status)
                }

                Label(circuit.provider.name, systemImage: "building.2")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(circuit.circuitType.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private func circuitIcon(status: String) -> some View {
        let color = Color.netBoxStatus(status)
        return Image(systemName: "point.3.connected.trianglepath.dotted")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 34, height: 34)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.12))
            )
    }
}

private struct VirtualCircuitRow: View {
    let circuit: VirtualCircuit

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            circuitIcon(status: circuit.status.value)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(circuit.cid.isEmpty ? circuit.display : circuit.cid)
                        .font(.headline.monospaced())
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Spacer(minLength: 8)

                    StatusBadge(status: circuit.status)
                }

                Label(circuit.providerNetwork?.name ?? "Provider network unavailable", systemImage: "cloud")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(circuit.circuitType.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private func circuitIcon(status: String) -> some View {
        let color = Color.netBoxStatus(status)
        return Image(systemName: "point.3.filled.connected.trianglepath.dotted")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 34, height: 34)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.12))
            )
    }
}
