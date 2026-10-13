import Foundation
import Security

/// Spotify secrets live in a 0600 file, not the Keychain: a self-signed build
/// gets a fresh Keychain trust entry per build, which prompted on every launch.
/// An old Keychain item is read once to migrate, then deleted.
enum SpotifySecretFile {
    private static var dir: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Vorssaint", isDirectory: true)
    }

    static func load(_ name: String, legacyAccount: String) -> Data? {
        let url = dir.appendingPathComponent(name)
        if let data = try? Data(contentsOf: url) { return data }
        guard let data = legacyKeychainRead(legacyAccount) else { return nil }
        save(data, name)
        legacyKeychainDelete(legacyAccount)
        return data
    }

    static func save(_ data: Data, _ name: String) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        let url = dir.appendingPathComponent(name)
        try? data.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    static func delete(_ name: String, legacyAccount: String) {
        try? FileManager.default.removeItem(at: dir.appendingPathComponent(name))
        legacyKeychainDelete(legacyAccount)
    }

    private static func legacyQuery(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "com.vorssaint.spotify",
         kSecAttrAccount as String: account]
    }

    private static func legacyKeychainRead(_ account: String) -> Data? {
        var q = legacyQuery(account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func legacyKeychainDelete(_ account: String) {
        SecItemDelete(legacyQuery(account) as CFDictionary)
    }
}
