import SwiftUI

struct CircuitDetailView: View {
    @State private var viewModel: CircuitDetailViewModel

    init(circuit: Circuit, repository: any CircuitsRepositoryProtocol, cache: OfflineCacheStore?) {
        _viewModel = State(initialValue: CircuitDetailViewModel(
            circuit: circuit,
            repository: repository,
            cache: cache
        ))
    }

    var body: some View {
        List {
            Section {
                CircuitHeader(circuit: viewModel.circuit)
            }

            Section("Details") {
                LabeledContent("Provider", value: viewModel.circuit.provider.name)
                LabeledContent("Type", value: viewModel.circuit.circuitType.name)
                LabeledContent("Status") { StatusBadge(status: viewModel.circuit.status) }
                if let commitRate = viewModel.circuit.commitRate {
                    LabeledContent("Commit Rate", value: formatKbps(commitRate))
                }
                if let distance = viewModel.circuit.distance {
                    LabeledContent("Distance", value: formatDistance(distance, unit: viewModel.circuit.distanceUnit))
                }
                if let installDate = viewModel.circuit.installDate, !installDate.isEmpty {
                    LabeledContent("Install Date", value: installDate)
                }
                if let terminationDate = viewModel.circuit.terminationDate, !terminationDate.isEmpty {
                    LabeledContent("Termination Date", value: terminationDate)
                }
                if !viewModel.circuit.description.isEmpty {
                    LabeledContent("Description", value: viewModel.circuit.description)
                }
                if !viewModel.circuit.comments.isEmpty {
                    LabeledContent("Comments", value: viewModel.circuit.comments)
                }
            }

            Section("Terminations") {
                if viewModel.isLoading && viewModel.terminations.isEmpty {
                    ProgressView()
                } else if let error = viewModel.error, viewModel.terminations.isEmpty {
                    ErrorView(error: error) {
                        Task { await viewModel.load() }
                    }
                } else if viewModel.terminations.isEmpty {
                    EmptyStateView(
                        title: "No Terminations",
                        systemImage: "cable.connector.slash",
                        message: "This circuit has no A or Z termination in NetBox."
                    )
                    .frame(minHeight: 220)
                } else {
                    ForEach(viewModel.terminations) { termination in
                        CircuitTerminationRow(termination: termination)
                    }
                }
            }
        }
        .navigationTitle(viewModel.circuit.cid.isEmpty ? viewModel.circuit.display : viewModel.circuit.cid)
        .safeAreaInset(edge: .top) {
            if viewModel.isShowingCachedData {
                CachedDataBanner(date: viewModel.cachedDate)
            }
        }
        .task {
            if viewModel.terminations.isEmpty {
                await viewModel.load()
            }
        }
        .refreshable {
            await viewModel.load()
        }
    }
}

struct VirtualCircuitDetailView: View {
    @State private var viewModel: VirtualCircuitDetailViewModel

    init(circuit: VirtualCircuit, repository: any CircuitsRepositoryProtocol, cache: OfflineCacheStore?) {
        _viewModel = State(initialValue: VirtualCircuitDetailViewModel(
            circuit: circuit,
            repository: repository,
            cache: cache
        ))
    }

    var body: some View {
        List {
            Section {
                VirtualCircuitHeader(circuit: viewModel.circuit)
            }

            Section("Details") {
                LabeledContent("Provider Network", value: viewModel.circuit.providerNetwork?.name ?? "—")
                LabeledContent("Type", value: viewModel.circuit.circuitType.name)
                LabeledContent("Status") { StatusBadge(status: viewModel.circuit.status) }
                if !viewModel.circuit.description.isEmpty {
                    LabeledContent("Description", value: viewModel.circuit.description)
                }
                if !viewModel.circuit.comments.isEmpty {
                    LabeledContent("Comments", value: viewModel.circuit.comments)
                }
            }

            Section("Virtual Terminations") {
                if viewModel.isLoading && viewModel.terminations.isEmpty {
                    ProgressView()
                } else if let error = viewModel.error, viewModel.terminations.isEmpty {
                    ErrorView(error: error) {
                        Task { await viewModel.load() }
                    }
                } else if viewModel.terminations.isEmpty {
                    EmptyStateView(
                        title: "No Virtual Terminations",
                        systemImage: "cable.connector.slash",
                        message: "This virtual circuit is not attached to any interfaces."
                    )
                    .frame(minHeight: 220)
                } else {
                    ForEach(viewModel.terminations) { termination in
                        VirtualCircuitTerminationRow(termination: termination)
                    }
                }
            }
        }
        .navigationTitle(viewModel.circuit.cid.isEmpty ? viewModel.circuit.display : viewModel.circuit.cid)
        .safeAreaInset(edge: .top) {
            if viewModel.isShowingCachedData {
                CachedDataBanner(date: viewModel.cachedDate)
            }
        }
        .task {
            if viewModel.terminations.isEmpty {
                await viewModel.load()
            }
        }
        .refreshable {
            await viewModel.load()
        }
    }
}

private struct CircuitHeader: View {
    let circuit: Circuit

    var body: some View {
        HStack(spacing: 14) {
            headerIcon(status: circuit.status.value, symbol: "point.3.connected.trianglepath.dotted")

            VStack(alignment: .leading, spacing: 6) {
                Text(circuit.cid.isEmpty ? circuit.display : circuit.cid)
                    .font(.title2.monospaced().weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                HStack(spacing: 6) {
                    StatusBadge(status: circuit.status)
                    Text(circuit.provider.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

private struct VirtualCircuitHeader: View {
    let circuit: VirtualCircuit

    var body: some View {
        HStack(spacing: 14) {
            headerIcon(status: circuit.status.value, symbol: "point.3.filled.connected.trianglepath.dotted")

            VStack(alignment: .leading, spacing: 6) {
                Text(circuit.cid.isEmpty ? circuit.display : circuit.cid)
                    .font(.title2.monospaced().weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                HStack(spacing: 6) {
                    StatusBadge(status: circuit.status)
                    Text(circuit.providerNetwork?.name ?? "Provider network unavailable")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

private struct CircuitTerminationRow: View {
    let termination: CircuitTermination

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label(sideLabel, systemImage: "cable.connector")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if termination.markConnected {
                    Label("Marked", systemImage: "checkmark.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }

            Label(locationLabel, systemImage: "mappin.and.ellipse")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                if let portSpeed = termination.portSpeed {
                    Label(formatKbps(portSpeed), systemImage: "speedometer")
                }
                if let upstreamSpeed = termination.upstreamSpeed {
                    Label("Up \(formatKbps(upstreamSpeed))", systemImage: "arrow.up")
                }
                if !termination.xconnectId.isEmpty {
                    Label(termination.xconnectId, systemImage: "number")
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)

            if !termination.description.isEmpty {
                Text(termination.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private var sideLabel: String {
        termination.termSide.isEmpty ? termination.display : "Side \(termination.termSide)"
    }

    private var locationLabel: String {
        if let site = termination.site {
            return site.name
        }
        if let providerNetwork = termination.providerNetwork {
            return providerNetwork.name
        }
        if let terminationType = termination.terminationType, let terminationId = termination.terminationId {
            return "\(terminationType) #\(terminationId)"
        }
        return "Termination target unavailable"
    }
}

private struct VirtualCircuitTerminationRow: View {
    let termination: VirtualCircuitTermination

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label(termination.interface.display, systemImage: "cable.connector")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let role = termination.role {
                    StatusBadge(status: role)
                }
            }

            if let device = termination.interface.device {
                Label(device.display, systemImage: "server.rack")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private func headerIcon(status: String, symbol: String) -> some View {
    let color = Color.netBoxStatus(status)
    return Image(systemName: symbol)
        .font(.system(size: 22, weight: .semibold))
        .foregroundStyle(color)
        .frame(width: 52, height: 52)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(color.opacity(0.12))
        )
}

private func formatKbps(_ value: Int) -> String {
    if value >= 1_000_000 {
        return "\(value / 1_000_000) Gbps"
    }
    if value >= 1_000 {
        return "\(value / 1_000) Mbps"
    }
    return "\(value) Kbps"
}

private func formatDistance(_ value: Double, unit: String?) -> String {
    let formatted = value.formatted(.number.precision(.fractionLength(0...2)))
    guard let unit, !unit.isEmpty else { return formatted }
    return "\(formatted) \(unit)"
}
