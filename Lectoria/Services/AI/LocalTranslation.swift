import Foundation
import Translation

// MARK: - LocalTranslation

/// Utilidades compartidas para la traducción local con el framework Translation de Apple.
/// La traducción real ocurre en cada vista mediante `.translationTask`, ya que las sesiones
/// de traducción deben estar vinculadas a una vista visible (el sistema puede presentar
/// la descarga del paquete de idioma).
enum LocalTranslation {
    /// `TranslationSession` no es `Sendable`; la sesión solo se usa mientras el cierre de
    /// `.translationTask` espera esta llamada, así que no hay accesos concurrentes.
    struct SessionBox: @unchecked Sendable {
        let session: TranslationSession
    }

    /// Traduce `text` con la sesión entregada por `.translationTask`.
    @concurrent
    static func translate(_ text: String, using box: SessionBox) async throws -> String {
        try await box.session.translate(text).targetText
    }

    /// Mapea el código de idioma del menú del lector al identificador del framework Translation.
    static func targetLanguage(for code: String) -> Locale.Language {
        Locale.Language(identifier: code == "zh" ? "zh-Hans" : code)
    }

    /// Mensaje de error amigable cuando la traducción local falla (p. ej. idioma no descargado).
    static func errorMessage(_ error: Error) -> String {
        String(localized: "No se pudo traducir el texto. Comprueba que el idioma esté descargado en Ajustes → Traducir, e inténtalo de nuevo.", comment: "Local translation error")
            + "\n\n(\(error.localizedDescription))"
    }
}
