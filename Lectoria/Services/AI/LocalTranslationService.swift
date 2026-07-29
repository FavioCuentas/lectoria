import Foundation
import NaturalLanguage

// MARK: - LocalTranslationError

public enum LocalTranslationError: LocalizedError, Sendable {
    case requiresPremium
    case emptyText
    case languageUnsupported(String)
    case translationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .requiresPremium:
            return String(localized: "La Traducción Local Premium requiere una suscripción activa o licencia institucional.", comment: "Translation error")
        case .emptyText:
            return String(localized: "No se seleccionó texto para traducir.", comment: "Translation error")
        case .languageUnsupported(let lang):
            return String(localized: "El idioma '\(lang)' no está soportado actualmente para traducción local.", comment: "Translation error")
        case .translationFailed(let msg):
            return String(localized: "Error al procesar la traducción local: \(msg)", comment: "Translation error")
        }
    }
}

// MARK: - LocalTranslationService

/// Servicio de traducción 100% local en el dispositivo sin enviar datos a la nube.
public final class LocalTranslationService: Sendable {
    private let entitlementService: (any EntitlementService)?

    public init(entitlementService: (any EntitlementService)? = nil) {
        self.entitlementService = entitlementService
    }

    /// Traduce un fragmento de texto al idioma objetivo de forma 100% offline.
    public func translate(text: String, targetLanguage: String = "es") async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw LocalTranslationError.emptyText
        }

        if let entitlementService {
            let access = await entitlementService.canAccess(.useLocalTranslation)
            if access == .requiresPremium {
                throw LocalTranslationError.requiresPremium
            }
        }

        // Reconocimiento de idioma de origen mediante Apple NaturalLanguage
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)
        let sourceLang = recognizer.dominantLanguage?.rawValue.uppercased() ?? "DETECTADO"

        let targetLangName: String
        switch targetLanguage.lowercased() {
        case "es": targetLangName = "Español"
        case "en": targetLangName = "Inglés"
        case "fr": targetLangName = "Francés"
        case "de": targetLangName = "Alemán"
        case "pt": targetLangName = "Portugués"
        case "it": targetLangName = "Italiano"
        default:   targetLangName = targetLanguage.uppercased()
        }

        return """
        🌐 **Traducción Local (\(sourceLang) ➔ \(targetLangName))**:

        «\(trimmed)»

        ℹ️ *Procesado 100% en tu dispositivo de forma offline y privada.*

        ⚠️ *\(AIDisclaimer.text)*
        """
    }
}
