//
//  WorkJamKeychain.swift
//  WorkScheduleApp
//
//  Stockage sécurisé des identifiants WorkJam via Keychain
//

import Foundation
import Security

final class WorkJamKeychain: @unchecked Sendable {

    static let shared = WorkJamKeychain()

    private let service = "com.shifter.workjam"

    private init() {}

    // MARK: - Sauvegarde

    func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    // MARK: - Lecture

    func retrieve(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    // MARK: - Suppression

    @discardableResult
    func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    @discardableResult
    func deleteAll() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Méthodes pratiques

    func saveToken(_ token: String) -> Bool { save(key: "wj_token", value: token) }
    func retrieveToken() -> String? { retrieve(key: "wj_token") }

    func saveEmployeeID(_ id: String) -> Bool { save(key: "wj_employee_id", value: id) }
    func retrieveEmployeeID() -> String? { retrieve(key: "wj_employee_id") }

    func saveEmail(_ email: String) -> Bool { save(key: "wj_email", value: email) }
    func retrieveEmail() -> String? { retrieve(key: "wj_email") }

    func savePassword(_ password: String) -> Bool { save(key: "wj_password", value: password) }
    func retrievePassword() -> String? { retrieve(key: "wj_password") }

    func isLoggedIn() -> Bool {
        retrieveToken() != nil && retrieveEmployeeID() != nil
    }

    func logout() {
        deleteAll()
    }
}
