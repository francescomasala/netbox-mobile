import Foundation

struct PagedResponse<T: Decodable & Sendable>: Decodable, Sendable {
    let count: Int
    let next: URL?
    let previous: URL?
    let results: [T]
}

struct StatusValue: Decodable, Hashable, Sendable {
    let value: String
    let label: String
}

struct AddressFamily: Decodable, Hashable, Sendable {
    let value: Int
    let label: String
}

/// Results from a paginated fetch, including the server-reported total count.
/// `isTruncated` is true when the local cap (500) was hit before all results were fetched.
struct PagedResult<T: Sendable>: Sendable {
    let items: [T]
    let totalCount: Int
    var isTruncated: Bool { totalCount > items.count }
}
