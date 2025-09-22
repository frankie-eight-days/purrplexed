//
//  KeychainHelper.swift
//  Purrplexed
//
//  Simple keychain wrapper for secure storage.
//

import Foundation
import Security

final class KeychainHelper {
    private let service: String
    
    init(service: String = Bundle.main.bundleIdentifier ?? "com.purrplexed.app") {
        self.service = service
    }
    
    // MARK: - String Storage
    
    func set(_ value: String, for key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return set(data, for: key)
    }
    
    func getString(for key: String) -> String? {
        guard let data = getData(for: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    // MARK: - Int Storage
    
    func set(_ value: Int, for key: String) -> Bool {
        return set(String(value), for: key)
    }
    
    func getInt(for key: String) -> Int? {
        guard let string = getString(for: key) else { return nil }
        return Int(string)
    }
    
    // MARK: - Date Storage
    
    func set(_ value: Date, for key: String) -> Bool {
        let timestamp = value.timeIntervalSince1970
        return set(String(timestamp), for: key)
    }
    
    func getDate(for key: String) -> Date? {
        guard let string = getString(for: key),
              let timestamp = Double(string) else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }
    
    // MARK: - Data Storage (Core Implementation)
    
    private func set(_ data: Data, for key: String) -> Bool {
        // First try to update existing item
        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
        
        if updateStatus == errSecSuccess {
            return true
        }
        
        // If item doesn't exist, create new one
        if updateStatus == errSecItemNotFound {
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
            ]
            
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            return addStatus == errSecSuccess
        }
        
        return false
    }
    
    private func getData(for key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }
    
    // MARK: - Delete
    
    func delete(for key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
