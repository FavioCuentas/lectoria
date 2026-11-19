import UIKit

// MARK: - DeviceIdentity

/// Identificador del dispositivo para el progreso de lectura sincronizado
/// (permite distinguir desde qué equipo se guardó). No identifica a la persona.
@MainActor
enum DeviceIdentity {
    static let current: String = {
        let key = "lectoria.deviceIdentifier"
        if let stored = UserDefaults.standard.string(forKey: key) { return stored }
        let identifier = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(identifier, forKey: key)
        return identifier
    }()
}
