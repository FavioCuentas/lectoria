import Foundation

// MARK: - BuildEnvironment

/// Entorno de compilación para separar configuraciones dev/staging/prod.
///
/// Los valores se resuelven en tiempo de compilación o lectura de
/// configuración. Nunca se almacenan claves secretas en el cliente.
enum BuildEnvironment: String, Sendable {
    case development
    case staging
    case production

    /// Entorno actual determinado por la configuración de compilación.
    static var current: BuildEnvironment {
        #if DEBUG
        .development
        #else
        // En un esquema real, esto se leería de un plist o variable de entorno
        .production
        #endif
    }
}

// MARK: - AppEnvironment

/// Configuración global de la aplicación según el entorno activo.
///
/// Centraliza URLs base, feature flags y configuración por entorno.
/// No almacena secretos; estos se obtienen de Keychain o del backend.
struct AppEnvironment: Sendable {
    let buildEnvironment: BuildEnvironment
    let bundleIdentifier: String
    let appVersion: String
    let buildNumber: String

    // MARK: - URLs base (configuradas remotamente en fases posteriores)

    var supabaseURL: String {
        switch buildEnvironment {
        case .development: "https://dev.supabase.lectoria.app"
        case .staging: "https://staging.supabase.lectoria.app"
        case .production: "https://api.lectoria.app"
        }
    }

    var supabaseAnonKey: String {
        switch buildEnvironment {
        case .development: "fake_dev_anon_key"
        case .staging: "fake_staging_anon_key"
        case .production: "fake_prod_anon_key"
        }
    }

    // MARK: - Feature flags (valores por defecto, actualizables remotamente)

    /// Número máximo de documentos para el plan gratuito.
    let freeDocumentLimit: Int = 5

    /// Número máximo de destacados para el plan gratuito.
    let freeHighlightLimit: Int = 30

    /// Número máximo de notas para el plan gratuito.
    let freeNoteLimit: Int = 15

    /// Acciones de IA por mes para el plan gratuito.
    let freeAIActionsPerMonth: Int = 3

    // MARK: - Factory

    /// Crea el AppEnvironment a partir de la configuración actual del bundle.
    static func current() -> AppEnvironment {
        let bundle = Bundle.main
        return AppEnvironment(
            buildEnvironment: BuildEnvironment.current,
            bundleIdentifier: bundle.bundleIdentifier ?? "com.lectoria.app",
            appVersion: bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            buildNumber: bundle.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        )
    }
}
