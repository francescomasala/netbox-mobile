import SwiftUI

struct PrefixListView: View {
    @State private var viewModel: PrefixListViewModel
    @State private var searchText = ""
    private let cache: OfflineCacheStore?

    init(repository: any IPAMRepositoryProtocol, cache: OfflineCacheStore? = nil) {
        self.cache = cache
        _viewModel = State(initialValue: PrefixListViewModel(repository: repository))
    }

    var body: some View {
        content
            .navigationTitle("Prefixes")
            .searchable(text: $searchText)
            .toolbar {
                ToolbarItem {
                    Picker("Family", selection: familySelection) {
                        Text("All").tag(Optional<Int>.none)
                        Text("IPv4").tag(Optional(4))
                        Text("IPv6").tag(Optional(6))
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 240)
                }
            }
            .safeAreaInset(edge: .top) {
                if viewModel.isTruncated {
                    TruncationBanner(totalCount: viewModel.totalCount)
                }
            }
            .task {
                if viewModel.prefixes.isEmpty {
                    await viewModel.load()
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.prefixes.isEmpty {
            ProgressView()
        } else if let error = viewModel.error, viewModel.prefixes.isEmpty {
            ErrorView(error: error) {
                Task { await viewModel.load() }
            }
        } else if groupedPrefixes.isEmpty {
            EmptyStateView(
                title: "No Prefixes",
                systemImage: "network",
                message: "No prefixes match the current filters."
            )
        } else {
            List {
                ForEach(groupedPrefixes, id: \.name) { group in
                    Section(group.name) {
                        ForEach(group.prefixes) { prefix in
                            NavigationLink {
                                PrefixDetailView(prefix: prefix, repository: viewModel.repository, cache: cache)
                            } label: {
                                PrefixRow(prefix: prefix)
                            }
                        }
                    }
                }
            }
        }
    }

    private var familySelection: Binding<Int?> {
        Binding {
            viewModel.selectedFamily
        } set: { selectedFamily in
            viewModel.selectedFamily = selectedFamily
            Task { await viewModel.load() }
        }
    }

    private var filteredPrefixes: [Prefix] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !query.isEmpty else {
            return viewModel.prefixes
        }

        return viewModel.prefixes.filter { prefix in
            prefix.prefix.lowercased().contains(query)
                || prefix.description.lowercased().contains(query)
        }
    }

    private var groupedPrefixes: [(name: String, prefixes: [Prefix])] {
        Dictionary(grouping: filteredPrefixes) { prefix in
            prefix.vrf?.name ?? "Global"
        }
        .map { (name: $0.key, prefixes: $0.value.sorted { $0.prefix < $1.prefix }) }
        .sorted { lhs, rhs in
            if lhs.name == "Global" { return true }
            if rhs.name == "Global" { return false }
            return lhs.name < rhs.name
        }
    }
}

// MARK: - Shared truncation banner

struct TruncationBanner: View {
    let totalCount: Int

    var body: some View {
        Label(
            "Showing first 500 of \(totalCount) results. Refine your search to see more.",
            systemImage: "exclamationmark.triangle.fill"
        )
        .font(.caption.weight(.medium))
        .foregroundStyle(.yellow)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.yellow.opacity(0.12))
    }
}

private struct PrefixRow: View {
    let prefix: Prefix

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: prefix.family.value == 6 ? "network" : "rectangle.3.group")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(prefix.family.value == 6 ? Color.purple : Color.blue)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill((prefix.family.value == 6 ? Color.purple : Color.blue).opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(prefix.prefix)
                        .font(.headline.monospaced())
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Spacer(minLength: 8)

                    HStack(spacing: 6) {
                        StatusBadge(status: prefix.status)
                        AddressFamilyBadge(family: prefix.family)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }

                if !prefix.description.isEmpty {
                    Text(prefix.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 10) {
                    Label(prefix.vrf?.name ?? "Global", systemImage: "globe")

                    if prefix.isPool {
                        Label("Pool", systemImage: "drop")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let utilization = prefix.utilization {
                    UtilizationMeter(value: utilization)
                }
            }
        }
        .padding(.vertical, 6)
    }
}
