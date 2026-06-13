# CLAUDE.md — NetBox Mobile

## Project overview

Native iOS/macOS app for NetBox (IPAM/DCIM). Universal app targeting iOS 26+ and macOS 26+. Swift 6, SwiftUI, no external dependencies.

## Build & test

```bash
# Build
xcodebuild build -scheme netbox-mobile -destination 'platform=iOS Simulator,name=iPhone 16'

# Test
xcodebuild test -scheme netbox-mobile -destination 'platform=iOS Simulator,name=iPhone 16'
```

Or use `BuildProject` / `RunAllTests` from the xcode-tools MCP server.

## Architecture

Feature-based MVVM. Layers, outer to inner:

- **View** (`*View.swift`) — SwiftUI only, no logic
- **ViewModel** (`*ViewModel.swift`) — `@Observable`, owns async tasks, calls repository
- **Repository** (`IPAMRepository`) — protocol-backed, calls NetBoxClient
- **NetBoxClient** — Swift actor, handles auth headers, pagination, TLS config
- **KeychainWrapper** — Swift actor, stores one token per connection keyed by UUID

Platform layout: `NavigationSplitView` on macOS/iPad, `NavigationStack` on iPhone (conditional on `#if os(iOS)`).

## Key files

| File | Purpose |
|---|---|
| `Core/Network/NetBoxClient.swift` | HTTP client — all API calls go here |
| `Core/Network/APIError.swift` | Typed error enum with user-facing messages |
| `Core/Keychain/KeychainWrapper.swift` | Secure token storage |
| `Core/Models/Connection.swift` | Connection config + UserDefaults persistence |
| `Features/IPAM/IPAMRepository.swift` | Repository protocol + actor implementation |
| `Features/Connections/ConnectionsViewModel.swift` | Manages active connection selection |

## Coding conventions

- Swift 6 strict concurrency — all cross-actor calls must be `await`ed
- Use `async/await`; do **not** use Combine
- ViewModels use `@Observable` (not `ObservableObject`)
- Actors for anything accessed from multiple contexts (network, keychain)
- No force-unwrapping; propagate errors with typed `throws`
- `Codable` models use `CodingKeys` for snake_case ↔ camelCase mapping

## Adding a new NetBox resource

1. Add a `Codable` model in `Core/Models/`
2. Add a fetch method to `IPAMRepositoryProtocol` and `IPAMRepository`
3. Add a method to `NetBoxClient` for the endpoint
4. Create `FeatureListView`, `FeatureListViewModel`, and (if needed) `FeatureDetailView` / `FeatureDetailViewModel` in a new `Features/<Name>/` folder
5. Add the new feature to the tab bar / navigation in `NetBoxMobileApp.swift`
6. Add unit tests in `netbox-mobileTests/`

## Testing approach

- Unit tests use Swift Testing framework (`import Testing`, `@Test`, `#expect`)
- No mocking framework; use protocol fakes (e.g. a mock `IPAMRepositoryProtocol`)
- `NetBoxClientTests` creates an in-memory `URLProtocol` stub — follow the same pattern
- Do **not** use `URLSession` mocks that diverge from real behavior

## What NOT to commit

- `xcuserdata/` — IDE state, already in `.gitignore`
- `DerivedData/` — build artefacts
- Secrets, `.env` files, provisioning profiles, `AuthKey_*.p8`

## Secrets handling

All API tokens go to the iOS Keychain via `KeychainWrapper`. The keychain service identifier is `it.hyperbit.netboxmobile`. Connection metadata (URL, name) is `UserDefaults`-backed; tokens are never written there.
