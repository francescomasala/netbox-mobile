import Foundation

enum APIError: LocalizedError {
    case unauthorized
    case forbidden
    case notFound
    case serverError(statusCode: Int)
    case decodingFailed(underlying: Error)
    case encodingFailed(underlying: Error)
    case networkUnavailable
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            "Unauthorized. Check the API token for this NetBox connection."
        case .forbidden:
            "Forbidden. This API token does not have permission to access that NetBox resource."
        case .notFound:
            "The requested NetBox resource was not found."
        case .serverError(let statusCode):
            "NetBox returned HTTP \(statusCode)."
        case .decodingFailed(let underlying):
            "The NetBox response could not be decoded: \(underlying.localizedDescription)"
        case .encodingFailed(let underlying):
            "The NetBox request could not be encoded: \(underlying.localizedDescription)"
        case .networkUnavailable:
            "The network is unavailable or the NetBox instance cannot be reached."
        case .invalidURL:
            "The NetBox URL is invalid."
        }
    }
}
