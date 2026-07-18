import Foundation
import Security

// MARK: - KeychainHelper

/// Utilidad nativa de iOS para almacenar y recuperar información de forma segura en el Keychain.
struct KeychainHelper: Sendable {
    static let service = "com.lectoria.app.auth"
    
    /// Guarda datos asociados a una clave. Si la clave ya existe, sobrescribe los datos.
    static func save(key: String, data: Data) {
        let deleteQuery = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ] as [String: Any]
        
        SecItemDelete(deleteQuery as CFDictionary)
        
        var query = deleteQuery
        query[kSecValueData as String] = data
        SecItemAdd(query as CFDictionary, nil)
    }
    
    /// Recupera datos asociados a una clave. Devuelve nil si no existe.
    static func load(key: String) -> Data? {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ] as [String: Any]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            return dataTypeRef as? Data
        }
        return nil
    }
    
    /// Elimina de forma permanente la clave y sus datos del Keychain.
    static func delete(key: String) {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ] as [String: Any]
        SecItemDelete(query as CFDictionary)
    }
}
