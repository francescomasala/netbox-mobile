import SwiftUI

struct ConnectionsView: View {
    @State private var viewModel = ConnectionsViewModel()

    var body: some View {
        Group {
#if os(macOS)
            NavigationSplitView {
                connectionList
                    .navigationTitle("Connections")
            } detail: {
                if let connection = viewModel.selectedConnection {
                    PrefixListView(repository: viewModel.repository(for: connection))
                } else {
                    ContentUnavailableView("No Connection Selected", systemImage: "server.rack")
                }
            }
#else
            NavigationStack {
                connectionList
                    .navigationTitle("Connections")
                    .navigationDestination(for: Connection.self) { connection in
                        PrefixListView(repository: viewModel.repository(for: connection))
                    }
            }
#endif
        }
        .task {
            await viewModel.refreshSetupPresentation()
        }
    }

    private var connectionList: some View {
        List {
            if viewModel.connections.isEmpty {
                ContentUnavailableView {
                    Label("No Connections", systemImage: "server.rack")
                } actions: {
                    Button {
                        viewModel.isPresentingSetup = true
                    } label: {
                        Label("Add Connection", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ForEach(viewModel.connections) { connection in
#if os(macOS)
                    Button {
                        Task { await viewModel.select(connection) }
                    } label: {
                        ConnectionRow(
                            connection: connection,
                            isSelected: connection.id == viewModel.selectedConnectionID
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            Task { await viewModel.delete(connection) }
                        }
                    }
#else
                    NavigationLink(value: connection) {
                        ConnectionRow(connection: connection, isSelected: false)
                    }
#endif
                }
#if os(iOS)
                .onDelete { offsets in
                    Task { await viewModel.deleteConnections(at: offsets) }
                }
#endif
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    viewModel.isPresentingSetup = true
                } label: {
                    Label("Add Connection", systemImage: "plus")
                }
            }
        }
        .sheet(
            isPresented: Binding(
                get: { viewModel.isPresentingSetup },
                set: { viewModel.isPresentingSetup = $0 }
            )
        ) {
            AddConnectionSheet(viewModel: viewModel)
        }
    }
}

private struct ConnectionRow: View {
    let connection: Connection
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : Color.accentColor)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.accentColor : Color.accentColor.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(connection.name)
                        .font(.headline)
                        .lineLimit(1)

                    if connection.isDefault {
                        Text("Default")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .foregroundStyle(.blue)
                            .background(
                                Capsule()
                                    .fill(.blue.opacity(0.12))
                            )
                    }

                    if connection.allowSelfSignedCertificates {
                        Image(systemName: "shield.slash")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                            .help("Self-signed certificate errors ignored")
                    }
                }

                Label {
                    Text(connection.baseURL.absoluteString)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } icon: {
                    Image(systemName: "link")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct AddConnectionSheet: View {
    let viewModel: ConnectionsViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var netBoxURL = ""
    @State private var apiToken = ""
    @State private var ignoreSelfSignedCertificates = false
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.tint.opacity(0.12))
                                .frame(width: 72, height: 72)
                            Image(systemName: "server.rack")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundStyle(.tint)
                        }
                        VStack(spacing: 4) {
                            Text("Add Connection")
                                .font(.title2.bold())
                            Text("Connect to a NetBox instance using its URL and an API token.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)
                .listSectionSeparator(.hidden, edges: .bottom)

                Section("Instance") {
                    TextField("Name", text: $name, prompt: Text("Contoso Prod (optional)"))
                        .autocorrectionDisabled()
#if os(iOS)
                        .textInputAutocapitalization(.never)
#endif

                    TextField("URL", text: $netBoxURL, prompt: Text("https://netbox.example.com"))
                        .autocorrectionDisabled()
#if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
#endif
                }

                Section("Authentication") {
                    SecureField("API Token", text: $apiToken, prompt: Text("Token xxxxxxxxxxxxxxxx"))
                }

                Section {
                    Toggle(isOn: $ignoreSelfSignedCertificates) {
                        Label("Ignore Self-Signed Errors", systemImage: "shield.slash")
                    }
                } footer: {
                    Text("Enable this only if your NetBox instance uses a self-signed TLS certificate.")
                }

                if let errorMessage {
                    Section {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                                .padding(.top, 1)
                            Text(errorMessage)
                                .foregroundStyle(.red)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Save")
                                .bold()
                        }
                    }
                    .disabled(isSaving || netBoxURL.isEmpty || apiToken.isEmpty)
                }
            }
        }
#if os(macOS)
        .frame(minWidth: 480, minHeight: 380)
#endif
    }

    @MainActor
    private func save() async {
        isSaving = true
        errorMessage = nil

        do {
            try await viewModel.saveConnection(
                name: name,
                netBoxURLString: netBoxURL,
                apiToken: apiToken,
                ignoreSelfSignedCertificates: ignoreSelfSignedCertificates
            )
            dismiss()
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}
