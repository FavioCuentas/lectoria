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
        try await Task.sleep(nanoseconds: 600_000_000) // Simular latencia de red
        
        // Si es una definición de diccionario
        if text.lowercased().hasPrefix("define la palabra:") {
            let word = text
                .replacingOccurrences(of: "Define la palabra:", with: "")
                .replacingOccurrences(of: "define la palabra:", with: "")
                .trimmingCharacters(in: .whitespaces)
            return """
            📖 \(word)
            
            Sustantivo / Adjetivo
            
            1. Concepto o término utilizado en el contexto académico para referirse a un elemento fundamental del tema estudiado.
            
            2. En sentido amplio, describe una cualidad o característica esencial dentro del campo de estudio.
            
            Ejemplo: «El autor utiliza "\(word)" para ilustrar la idea central del capítulo.»
            
            Sinónimos: concepto, noción, término, idea.
            """
        }
        
        return """
        Esta sección aborda el concepto de '\(text.prefix(80))...'
        
        En términos sencillos, el autor presenta una idea clave que se conecta con el tema principal del texto. Se explican las bases teóricas y se proporcionan ejemplos que ayudan a comprender mejor el contexto.
        
        💡 Punto clave: Este fragmento es importante porque establece las bases para los conceptos que se desarrollan más adelante en la lectura.
        """
    }
    
    public func simplify(text: String, sessionToken: String?) async throws -> String {
        if shouldFail { throw mockError() }
        try await Task.sleep(nanoseconds: 500_000_000)
        return """
        En palabras sencillas:
        
        Este texto habla sobre '\(text.prefix(60))...'
        
        Lo que quiere decir es que hay una idea principal que el autor quiere comunicar. Piensa en ello como una explicación paso a paso de algo que puede parecer complicado, pero en realidad es más simple de lo que parece.
        
        ✅ Resumen simple: El autor explica un concepto importante de forma directa.
        """
    }
    
    public func translate(text: String, targetLanguage: String, sessionToken: String?) async throws -> String {
        if shouldFail { throw mockError() }
        try await Task.sleep(nanoseconds: 500_000_000)
        
        let langName: String
        switch targetLanguage.lowercased() {
        case "en": langName = "Inglés"
        case "fr": langName = "Francés"
        case "de": langName = "Alemán"
        case "pt": langName = "Portugués"
        case "it": langName = "Italiano"
        case "ja": langName = "Japonés"
        case "zh": langName = "Chino"
        case "ko": langName = "Coreano"
        case "es": langName = "Español"
        default:   langName = targetLanguage.uppercased()
        }
        
        return """
        🌐 Traducción al \(langName):
        
        «\(text.prefix(200))»
        
        ➡️ [Traducción simulada — conecta un servicio de IA real (Supabase + OpenAI/Gemini) para obtener traducciones reales]
        
        Nota: Esta es una respuesta de prueba. Cuando configures tu servidor de Supabase con las Edge Functions de IA, la traducción será precisa y en tiempo real.
        """
    }
    
    public func summarize(text: String, sessionToken: String?) async throws -> String {
        if shouldFail { throw mockError() }
        try await Task.sleep(nanoseconds: 500_000_000)
        return """
        📄 Resumen del fragmento:
        
        El texto seleccionado presenta las ideas principales sobre el tema tratado. Los puntos clave son:
        
        • Se introduce el concepto central del capítulo
        • Se proporcionan ejemplos y evidencias de soporte
        • Se establece una conexión con temas previos
        
        Este fragmento es fundamental para comprender el desarrollo posterior del argumento del autor.
        """
    }
    
    public func generateQuestions(text: String, sessionToken: String?) async throws -> String {
        if shouldFail { throw mockError() }
        try await Task.sleep(nanoseconds: 500_000_000)
        return """
        ❓ Preguntas de estudio:
        
        1. ¿Cuál es la idea principal que presenta el autor en este fragmento?
        
        2. ¿Cómo se relaciona este concepto con los temas tratados anteriormente?
        
        3. ¿Qué evidencias o ejemplos utiliza el autor para sustentar su argumento?
        
        4. ¿Podrías explicar este concepto con tus propias palabras?
        
        5. ¿Qué implicaciones tiene esta idea para el resto del texto?
        """
    }
    
    private func mockError() -> Error {
        NSError(domain: "MockAI", code: 500, userInfo: [NSLocalizedDescriptionKey: "Error simulado en el servicio de IA."])
    }
}
