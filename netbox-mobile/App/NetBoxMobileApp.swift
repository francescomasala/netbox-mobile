import SwiftUI

@main
struct NetBoxMobileApp: App {
    @State private var connectionsViewModel = ConnectionsViewModel()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(connectionsViewModel)
        }
    }
}

// MARK: - Root view

struct AppRootView: View {
    @Environment(ConnectionsViewModel.self) private var connectionsViewModel
    @State private var dependencies: AppDependencies?

    var body: some View {
        Group {
            if let deps = dependencies {
                AppMainView(dependencies: deps)
                    .environment(deps)
                    .environment(\.appDependencies, deps)
                    .environment(connectionsViewModel)
            } else {
                ProgressView("Connecting…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { connectionsViewModel.isPresentingSetup },
                set: { connectionsViewModel.isPresentingSetup = $0 }
            )
        ) {
            ConnectionsView()
                .environment(connectionsViewModel)
        }
        .task {
            await connectionsViewModel.refreshSetupPresentation()
        }
        .task(id: connectionsViewModel.selectedConnection?.id) {
            if let connection = connectionsViewModel.selectedConnection {
                dependencies = connectionsViewModel.appDependencies(for: connection)
            } else {
                dependencies = nil
            }
        }
    }
}

// MARK: - Main view (receives fully-resolved dependencies)

struct AppMainView: View {
    let dependencies: AppDependencies

    var body: some View {
#if os(iOS)
        iOSTabView
#else
        MacShellView(dependencies: dependencies)
#endif
    }

#if os(iOS)
    private var iOSTabView: some View {
        TabView {
            NavigationStack {
                PrefixListView(repository: dependencies.ipamRepository)
            }
            .tabItem { Label("IPAM", systemImage: "list.bullet") }

            NavigationStack {
                DeviceListView(repository: dependencies.dcimRepository)
            }
            .tabItem { Label("DCIM", systemImage: "server.rack") }

            NavigationStack {
                SearchView(
                    dcimRepository: dependencies.dcimRepository,
                    ipamRepository: dependencies.ipamRepository
                )
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }

            NavigationStack {
                ConnectionsView()
            }
            .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
#endif
}

// MARK: - macOS split view

#if os(macOS)
private enum SidebarItem: String, Hashable {
    case prefixes = "Prefixes"
    case devices = "Devices"
    case search = "Search"
    case connections = "Connections"
}

struct MacShellView: View {
    let dependencies: AppDependencies
    @Environment(ConnectionsViewModel.self) private var connectionsViewModel
    @State private var selection: SidebarItem? = .prefixes

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("IPAM") {
                    Label("Prefixes", systemImage: "list.bullet")
                        .tag(SidebarItem.prefixes)
                }
                Section("DCIM") {
                    Label("Devices", systemImage: "server.rack")
                        .tag(SidebarItem.devices)
                }
                Label("Search", systemImage: "magnifyingglass")
                    .tag(SidebarItem.search)
                Label("Connections", systemImage: "gear")
                    .tag(SidebarItem.connections)
            }
            .navigationTitle("NetBox")
        } detail: {
            NavigationStack {
                switch selection ?? .prefixes {
                case .prefixes:
                    PrefixListView(repository: dependencies.ipamRepository)
                case .devices:
                    DeviceListView(repository: dependencies.dcimRepository)
                case .search:
                    SearchView(
                        dcimRepository: dependencies.dcimRepository,
                        ipamRepository: dependencies.ipamRepository
                    )
                case .connections:
                    ConnectionsView()
                        .environment(connectionsViewModel)
                }
            }
        }
    }
}
#endif
