import Foundation
import Observation

// MARK: - MockAIService

/// Implementación simulada de `AIService` para pruebas y vistas previas.
@Observable
public final class MockAIService: AIService, @unchecked Sendable {
    public var hasConsentedToAI: Bool = false
    public var shouldFail = false
    
    public init(hasConsentedToAI: Bool = false) {
        self.hasConsentedToAI = hasConsentedToAI
    }
    
    public func explain(text: String, sessionToken: String?) async throws -> String {
        if shouldFail { throw mockError() }
        return "Explicación de Lectoria AI: El texto hace referencia a '\(text)'. Esto representa un pilar conceptual fundamental de estudio."
    }
    
    public func simplify(text: String, sessionToken: String?) async throws -> String {
        if shouldFail { throw mockError() }
        return "Simplificación de Lectoria AI: En palabras sencillas, esto significa que '\(text)' es simplemente la idea básica explicada con claridad."
    }
    
    public func translate(text: String, targetLanguage: String, sessionToken: String?) async throws -> String {
        if shouldFail { throw mockError() }
        return "Traducción de Lectoria AI (Idioma: \(targetLanguage)): [\(text)] traducido correctamente."
    }
    
    public func summarize(text: String, sessionToken: String?) async throws -> String {
        if shouldFail { throw mockError() }
        return "Resumen de Lectoria AI: Este fragmento describe detalladamente el concepto principal, reduciéndolo a sus componentes clave."
    }
    
    public func generateQuestions(text: String, sessionToken: String?) async throws -> String {
        if shouldFail { throw mockError() }
        return "Preguntas de Estudio de Lectoria AI:\n1. ¿Cuál es el significado principal de '\(text)'?\n2. ¿Cómo se relaciona este concepto con la teoría descrita?"
    }
    
    private func mockError() -> Error {
        NSError(domain: "MockAI", code: 500, userInfo: [NSLocalizedDescriptionKey: "Error simulado en el servicio de IA."])
    }
}
