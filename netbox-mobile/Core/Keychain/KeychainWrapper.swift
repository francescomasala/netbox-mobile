import Foundation
import Security

enum KeychainError: LocalizedError {
    case itemNotFound
    case unexpectedData
    case unhandled(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            "No API token was found for this connection."
        case .unexpectedData:
            "The saved API token could not be read."
        case .unhandled(let status):
            "The Keychain operation failed with status \(status)."
        }
    }
}

actor KeychainWrapper {
    private let service: String

    init(service: String = "it.hyperbit.netboxmobile") {
        self.service = service
    }

    func save(token: String, for connectionID: UUID) throws {
        let tokenData = Data(token.utf8)
        let query = query(for: connectionID)
        let attributes: [String: Any] = [
            kSecValueData as String: tokenData
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var addQuery = query
            addQuery[kSecValueData as String] = tokenData

            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unhandled(status: addStatus)
            }
        default:
            throw KeychainError.unhandled(status: updateStatus)
        }
    }

    func load(for connectionID: UUID) throws -> String {
        var query = query(for: connectionID)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = kCFBooleanTrue

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status != errSecItemNotFound else {
            throw KeychainError.itemNotFound
        }

        guard status == errSecSuccess else {
            throw KeychainError.unhandled(status: status)
        }

        guard
            let data = result as? Data,
            let token = String(data: data, encoding: .utf8)
        else {
            throw KeychainError.unexpectedData
        }

        return token
    }

    func delete(for connectionID: UUID) throws {
        let status = SecItemDelete(query(for: connectionID) as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandled(status: status)
        }
    }

    private func query(for connectionID: UUID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: connectionID.uuidString
        ]
    }
}
