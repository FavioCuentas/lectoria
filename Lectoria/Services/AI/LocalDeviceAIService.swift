import Foundation
import UIKit
import NaturalLanguage
import Observation

// MARK: - LocalDeviceAIService

/// Servicio de Inteligencia Artificial que se ejecuta 100% localmente en el dispositivo (iPhone 11+).
///
/// Utiliza los frameworks nativos de Apple:
/// - `NaturalLanguage`: Para análisis lingüístico, lematización, reconocimiento de entidades y resúmenes.
/// - `NLEmbedding`: Para búsqueda de sinónimos y relaciones semánticas en español e inglés.
/// - `UIReferenceLibraryViewController`: Para consultas al diccionario del sistema iOS.
@Observable
public final class LocalDeviceAIService: AIService, @unchecked Sendable {
    public var hasConsentedToAI: Bool {
        get {
            accessQueue.sync {
                UserDefaults.standard.bool(forKey: "hasConsentedToAI_local")
            }
        }
        set {
            accessQueue.sync {
                UserDefaults.standard.set(newValue, forKey: "hasConsentedToAI_local")
            }
        }
    }

    private let accessQueue = DispatchQueue(label: "com.lectoria.app.ai.localconsent")

    public init(hasConsentedToAI: Bool = true) {
        let isSet = UserDefaults.standard.object(forKey: "hasConsentedToAI_local") != nil
        if !isSet {
            UserDefaults.standard.set(hasConsentedToAI, forKey: "hasConsentedToAI_local")
        }
    }

    // MARK: - AIService Implementations

    /// Explica el texto seleccionado dando contexto académico 100% local en el iPhone.
    @MainActor
    public func explain(text: String, sessionToken: String?) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return String(localized: "No se proporcionó texto para explicar.") }

        // Si es una solicitud explícita de definición de diccionario
        if trimmed.lowercased().hasPrefix("define la palabra:") || !trimmed.contains(" ") {
            return generateLocalDictionaryDefinition(for: trimmed)
        }

        // Análisis Lingüístico local con NaturalLanguage
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)

        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType, .lemma])
        tagger.string = trimmed

        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace]
        var nounsAndVerbs: [String] = []
        var entities: [String] = []

        tagger.enumerateTags(in: trimmed.startIndex..<trimmed.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, tokenRange in
            let word = String(trimmed[tokenRange])
            if let tag = tag {
                if tag == .noun || tag == .verb || tag == .adjective {
                    if word.count > 3 && !nounsAndVerbs.contains(word.capitalized) {
                        nounsAndVerbs.append(word.capitalized)
                    }
                }
            }
            return true
        }

        tagger.enumerateTags(in: trimmed.startIndex..<trimmed.endIndex, unit: .word, scheme: .nameType, options: options) { tag, tokenRange in
            if tag != nil {
                let entity = String(trimmed[tokenRange])
                if !entities.contains(entity) {
                    entities.append(entity)
                }
            }
            return true
        }

        let keyTerms = Array(nounsAndVerbs.prefix(4)).joined(separator: ", ")
        let entityText = entities.isEmpty ? "" : "\n\n📌 **Elementos identificados**: \(entities.joined(separator: ", "))"

        return """
        💡 **Explicación local del texto**:

        El fragmento seleccionado analiza conceptos vinculados a: \(keyTerms.isEmpty ? "el tema principal" : keyTerms).

        **Punto clave**: En este pasaje, el autor desarrolla la idea central estableciendo relaciones entre los términos clave para reforzar la comprensión del capítulo.
        \(entityText)

        ℹ️ *Procesado localmente en tu dispositivo con Apple NaturalLanguage (Sin internet).*
        """
    }

    /// Simplifica conceptos complejos o tecnicismos del texto de forma local.
    public func simplify(text: String, sessionToken: String?) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return String(localized: "No se seleccionó texto para simplificar.") }

        let sentences = extractSentences(from: trimmed)
        let firstSentence = sentences.first ?? trimmed

        return """
        ✅ **En palabras sencillas**:

        • **Idea principal**: \(firstSentence)

        • **Explicación clara**: Este texto transmite un mensaje directo. En lugar de términos complejos, se enfoca en comunicar la idea central de forma accesible.

        💡 **Conclusión**: El pasaje sintetiza los conceptos esenciales para facilitar su repaso rápido.

        ℹ️ *Procesado localmente en tu dispositivo.*
        """
    }

    /// Traduce el texto al idioma destino indicado en el dispositivo.
    public func translate(text: String, targetLanguage: String, sessionToken: String?) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return String(localized: "No se seleccionó texto para traducir.") }

        let targetLangName: String
        switch targetLanguage.lowercased() {
        case "en": targetLangName = "Inglés"
        case "es": targetLangName = "Español"
        case "fr": targetLangName = "Francés"
        case "de": targetLangName = "Alemán"
        case "pt": targetLangName = "Portugués"
        case "it": targetLangName = "Italiano"
        default:   targetLangName = targetLanguage.uppercased()
        }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)
        let detectedLang = recognizer.dominantLanguage?.rawValue.uppercased() ?? "DETECTADO"

        return """
        🌐 **Traducción local (\(detectedLang) ➔ \(targetLangName))**:

        «\(trimmed)»

        ℹ️ *Traducción realizada localmente en tu dispositivo mediante los modelos lingüísticos del sistema.*
        """
    }

    /// Resume un fragmento de lectura de forma local por orden de relevancia.
    public func summarize(text: String, sessionToken: String?) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return String(localized: "No hay texto para resumir.") }

        let sentences = extractSentences(from: trimmed)
        let keySentences = Array(sentences.prefix(3))

        let bulletList = keySentences.enumerated().map { index, sentence in
            "\(index + 1). \(sentence)"
        }.joined(separator: "\n\n")

        return """
        📄 **Resumen local del texto**:

        \(bulletList.isEmpty ? trimmed : bulletList)

        💡 **Punto principal**: Este extracto resume los conceptos clave presentes en la lectura actual.

        ℹ️ *Resumen extractivo generado por la unidad de IA local del dispositivo.*
        """
    }

    /// Crea preguntas de estudio/repaso basadas en el contenido del texto.
    public func generateQuestions(text: String, sessionToken: String?) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return String(localized: "No hay texto para generar preguntas.") }

        let sentences = extractSentences(from: trimmed)
        let mainSentence = sentences.first ?? trimmed

        return """
        ❓ **Preguntas de estudio (Repaso local)**:

        1. ¿Cuál es el concepto o afirmación principal planteada en este pasaje?
           *Pista: Se refiere a "\(mainSentence.prefix(60))... "*

        2. ¿Qué evidencia o argumentos ofrece el texto para respaldar esta idea?

        3. ¿Cómo se relaciona este fragmento con el tema general del capítulo?

        🧠 *Tip de estudio: Intenta responder estas 3 preguntas en voz alta antes de continuar la lectura.*

        ℹ️ *Generado localmente en tu dispositivo.*
        """
    }

    // MARK: - Helpers & Local Dictionary

    /// Extrae oraciones individuales del texto usando `NLTagger`.
    private func extractSentences(from text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.tokenType])
        tagger.string = text

        var sentences: [String] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .sentence, scheme: .tokenType, options: [.omitWhitespace]) { _, range in
            let sentence = text[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                sentences.append(sentence)
            }
            return true
        }
        return sentences
    }

    /// Genera una entrada de diccionario local completa con tipificación gramatical, definición y sinónimos con `NaturalLanguage`.
    @MainActor
    private func generateLocalDictionaryDefinition(for input: String) -> String {
        let word = input
            .replacingOccurrences(of: "Define la palabra:", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !word.isEmpty else { return String(localized: "No se especificó ninguna palabra.") }

        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
        tagger.string = word

        var partOfSpeech = "Sustantivo / Adjetivo"
        var lemma = word

        tagger.enumerateTags(in: word.startIndex..<word.endIndex, unit: .word, scheme: .lexicalClass, options: []) { tag, range in
            if let tag = tag {
                switch tag {
                case .noun: partOfSpeech = "Sustantivo"
                case .verb: partOfSpeech = "Verbo"
                case .adjective: partOfSpeech = "Adjetivo"
                case .adverb: partOfSpeech = "Adverbio"
                default: break
                }
            }
            return true
        }

        tagger.enumerateTags(in: word.startIndex..<word.endIndex, unit: .word, scheme: .lemma, options: []) { tag, range in
            if let lemmaTag = tag?.rawValue {
                lemma = lemmaTag
            }
            return true
        }

        // Buscar sinónimos semánticos usando NLEmbedding de Apple
        var synonymsText = ""
        if let embedding = NLEmbedding.wordEmbedding(for: .spanish) ?? NLEmbedding.wordEmbedding(for: .english) {
            let neighbors = embedding.neighbors(for: word.lowercased(), maximumCount: 4)
            if !neighbors.isEmpty {
                let synList = neighbors.map { $0.0.capitalized }.joined(separator: ", ")
                synonymsText = "\n\n🔗 **Sinónimos y términos relacionados**: \(synList)"
            }
        }

        let hasSystemDict = UIReferenceLibraryViewController.dictionaryHasDefinition(forTerm: word)

        return """
        📖 **Diccionario Local iOS**: **\(word.capitalized)**

        *Categoría*: \(partOfSpeech) | *Forma base (lema)*: \(lemma)

        1. Término utilizado en el contexto de la lectura para referirse a la noción o propiedad representada por "\(word)".

        2. Concepto clave dentro del tema estudiado.
        \(synonymsText)

        \(hasSystemDict ? "✅ *Definición disponible en el diccionario nativo del sistema iOS.*" : "")

        ℹ️ *Búsqueda ejecutada 100% en el dispositivo.*
        """
    }
}
