import Foundation

// MARK: - AIService

/// Contrato para el asistente de inteligencia artificial académica de Lectoria.
public protocol AIService: AnyObject, Sendable {
    /// Determina si el usuario ha otorgado consentimiento informado para el uso de la IA.
    var hasConsentedToAI: Bool { get set }
    
    /// Explica el texto seleccionado dando contexto académico.
    func explain(text: String, sessionToken: String?) async throws -> String
    
    /// Simplifica conceptos complejos o tecnicismos del texto.
    func simplify(text: String, sessionToken: String?) async throws -> String
    
    /// Traduce el texto al idioma destino indicado.
    func translate(text: String, targetLanguage: String, sessionToken: String?) async throws -> String
    
    /// Resume un fragmento de lectura o capítulo.
    func summarize(text: String, sessionToken: String?) async throws -> String
    
    /// Crea preguntas de estudio/repaso basadas en el contenido del texto.
    func generateQuestions(text: String, sessionToken: String?) async throws -> String
}
