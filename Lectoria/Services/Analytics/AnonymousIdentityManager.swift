import Foundation

// MARK: - AnonymousIdentityManager

/// Gestiona la generación y persistencia segura en Keychain de un identificador de instalación anónimo (`installation_id`).
///
/// Permite medir retención y comportamiento agregado sin almacenar información personal ni UUIDs de dispositivo rastreables.
public final class AnonymousIdentityManager: Sendable {
    public static let shared = AnonymousIdentityManager()

    private let keychainKey = "com.orvexa.Lectoria.installation_id"

    public var installationID: UUID {
        if let data = KeychainHelper.load(key: keychainKey),
           let uuidString = String(data: data, encoding: .utf8),
           let uuid = UUID(uuidString: uuidString) {
            return uuid
        }

        let newUUID = UUID()
        if let data = newUUID.uuidString.data(using: .utf8) {
            KeychainHelper.save(key: keychainKey, data: data)
        }
        return newUUID
    }
}
