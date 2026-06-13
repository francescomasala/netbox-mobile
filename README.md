# NetBox Mobile

A native iOS/macOS app for browsing [NetBox](https://netbox.dev) — the open-source IP Address Management (IPAM) and Data Center Infrastructure Management (DCIM) platform.

## Features

- **Multiple connections** — connect to any number of NetBox instances, switching between them at any time
- **IPAM — Prefix browser** — list, search, and filter IP prefixes by address family (IPv4/IPv6) and VRF
- **Prefix details** — view metadata, utilization, and all contained IP addresses
- **Status visualization** — color-coded badges and utilization meters
- **Secure credential storage** — API tokens stored in the iOS Keychain, never on disk
- **Self-signed certificate support** — optional toggle for lab/test environments
- **Universal** — runs natively on iPhone, iPad, and Mac (Designed for iPad / Catalyst)

## Requirements

| Requirement | Version |
|---|---|
| iOS | 26.0+ |
| macOS | 26.0+ |
| Xcode | 26.0+ |
| Swift | 6.0+ |

No external dependencies — only Apple frameworks.

## Getting Started

1. Clone the repository
2. Open `netbox-mobile.xcodeproj` in Xcode
3. Select a target device or simulator
4. Build and run (`⌘R`)

### Connecting to NetBox

1. Open the **Connections** tab
2. Tap **+** and enter:
   - A display name for the connection
   - The base URL of your NetBox instance (e.g. `https://netbox.example.com`)
   - A NetBox API token (Settings → API Tokens in NetBox)
3. Enable **Allow self-signed certificate** if your instance uses a self-signed TLS cert
4. Tap **Save**

## Architecture

The project follows a feature-based MVVM architecture:

```
netbox-mobile/
├── App/                    # Entry point
├── Core/
│   ├── Keychain/           # Secure token storage (Swift actor)
│   ├── Models/             # Codable data models (Prefix, IPAddress, VRF, Connection)
│   └── Network/            # NetBox HTTP client (Swift actor, async/await)
├── Features/
│   ├── Connections/        # Connection management UI + ViewModel
│   └── IPAM/               # Prefix list, prefix detail UI + ViewModels + Repository
└── Shared/
    ├── Extensions/         # Color helpers
    └── Views/              # Reusable components (StatusBadge, UtilizationMeter, …)
```

**Key patterns:**
- `@Observable` ViewModels with `async/await` for all network calls
- Swift actors for thread-safe Keychain and network access
- Protocol-based repository (`IPAMRepositoryProtocol`) for testability
- Platform-adaptive layout: `NavigationSplitView` on macOS/iPad, `NavigationStack` on iPhone

## Testing

Run the test suite from Xcode (`⌘U`) or via CLI:

```bash
xcodebuild test -scheme netbox-mobile -destination 'platform=iOS Simulator,name=iPhone 16'
```

Test targets:
- `netbox-mobileTests` — unit tests for Keychain, NetBoxClient, and IPAM repository
- `netbox-mobileUITests` — UI tests (WIP)

## Security

- API tokens are stored exclusively in the iOS Keychain with a per-connection UUID key
- No secrets are hardcoded anywhere in the codebase
- HTTPS is enforced by default; the self-signed certificate bypass is opt-in per connection and should only be used in trusted lab environments
- Connection metadata (URL, display name) is stored in `UserDefaults`; only the token goes to Keychain

## License

MIT
