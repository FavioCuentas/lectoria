import Foundation
import Observation

// MARK: - AnalyticsPrivacyManager

/// Gestiona la configuración de privacidad y el consentimiento del usuario para enviar analítica anónima.
@Observable
public final class AnalyticsPrivacyManager: @unchecked Sendable {
    public static let shared = AnalyticsPrivacyManager()

    private let userDefaultsKey = "com.orvexa.Lectoria.isAnalyticsEnabled"

    public var isAnalyticsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isAnalyticsEnabled, forKey: userDefaultsKey)
        }
    }

    public init() {
        // Por defecto es verdadero (opt-out disponible en Ajustes/Perfil)
        if UserDefaults.standard.object(forKey: userDefaultsKey) == nil {
            self.isAnalyticsEnabled = true
        } else {
            self.isAnalyticsEnabled = UserDefaults.standard.bool(forKey: userDefaultsKey)
        }
    }
}
