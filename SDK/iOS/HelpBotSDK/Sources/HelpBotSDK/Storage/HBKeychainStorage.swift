import Foundation
import Security

/**
 Keychain 加密存储（用于保存 token 等敏感信息）。

 - 安全：Keychain 由系统加密保护；SDK 默认不落日志。
 - 稳定：所有调用 try-catch 风格收口（返回 Bool / nil），避免影响宿主稳定性。
 */
final class HBKeychainStorage {
    private let service: String

    init(service: String) {
        self.service = service
    }

    func putString(_ key: String, _ value: String) -> Bool {
        guard !key.isEmpty else { return false }
        guard let data = value.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        // 先删除旧值再写入，避免更新失败导致多条记录
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        return status == errSecSuccess
    }

    func getString(_ key: String) -> String? {
        guard !key.isEmpty else { return nil }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        guard let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func remove(_ key: String) -> Bool {
        guard !key.isEmpty else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}


