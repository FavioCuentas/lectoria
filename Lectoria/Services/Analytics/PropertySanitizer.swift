import Foundation

// MARK: - PropertySanitizer

/// Sanitiza y filtra las propiedades de los eventos de analítica para evitar fugas de información privada (Zero PII / Zero Content).
public struct PropertySanitizer: Sendable {
    private static let forbiddenKeys: Set<String> = [
        "title", "author", "text", "selectedtext", "selected_text", "highlighttext",
        "highlight_text", "notebody", "note_body", "query", "prompt", "response",
        "email", "name", "token", "password", "filepath", "file_path", "filename", "file_name",
        "url", "search_term", "searchterm", "word", "definition",
        "document_id", "documentid", "publication_id", "publicationid", "doc_id", "uuid", "id"
    ]

    /// Formatos permitidos exclusivamente para reading_session_ended.
    public static let allowedReadingSessionFormats: Set<String> = [
        "pdf", "epub", "txt", "markdown", "pptx", "pasted_text"
    ]

    /// Claves permitidas exclusivamente para reading_session_ended (Allowlist cerrada).
    public static let allowedReadingSessionKeys: Set<String> = [
        "duration_seconds", "format"
    ]

    /// Sanitiza un diccionario de propiedades eliminando claves prohibidas y garantizando que solo contenga metadatos agregados.
    public static func sanitize(_ properties: [String: Any]) -> [String: String] {
        sanitize(properties, for: nil)
    }

    /// Sanitiza aplicando reglas generales o allowlist estricta según el tipo de evento.
    public static func sanitize(_ properties: [String: Any], for eventName: AnalyticsEventName?) -> [String: String] {
        if eventName == .readingSessionEnded {
            return sanitizeReadingSessionProperties(properties)
        }

        var sanitized: [String: String] = [:]

        for (key, value) in properties {
            let lowerKey = key.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

            // Filtrar claves prohibidas por privacidad
            if forbiddenKeys.contains(lowerKey) {
                continue
            }

            // Convertir valores permitidos a cadenas anonimizadas
            if let stringValue = value as? String {
                sanitized[key] = stringValue.prefix(100).description
            } else if let boolValue = value as? Bool {
                sanitized[key] = boolValue ? "true" : "false"
            } else if let intValue = value as? Int {
                sanitized[key] = String(intValue)
            } else if let doubleValue = value as? Double {
                sanitized[key] = String(format: "%.2f", doubleValue)
            }
        }

        return sanitized
    }

    private static func sanitizeReadingSessionProperties(_ properties: [String: Any]) -> [String: String] {
        var result: [String: String] = [:]

        // 1. duration_seconds
        if let durationVal = properties["duration_seconds"] {
            if let intVal = durationVal as? Int {
                result["duration_seconds"] = String(max(0, intVal))
            } else if let doubleVal = durationVal as? Double {
                result["duration_seconds"] = String(max(0, Int(doubleVal)))
            } else if let strVal = durationVal as? String, let intParsed = Int(strVal) {
                result["duration_seconds"] = String(max(0, intParsed))
            }
        }

        // 2. format
        if let formatVal = properties["format"] as? String {
            let normalized = formatVal.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if allowedReadingSessionFormats.contains(normalized) {
                result["format"] = normalized
            }
        }

        return result
    }

    /// Clasifica el tamaño de un archivo en rangos anonimizados (buckets).
    public static func bucketFileSize(_ bytes: Int64) -> String {
        let mb = Double(bytes) / (1024.0 * 1024.0)
        switch mb {
        case ..<1.0: return "<1MB"
        case 1.0..<5.0: return "1-5MB"
        case 5.0..<15.0: return "5-15MB"
        default: return ">15MB"
        }
    }

    /// Clasifica una duración en segundos en rangos anonimizados.
    public static func bucketDuration(_ seconds: Int) -> String {
        switch seconds {
        case ..<60: return "<1min"
        case 60..<300: return "1-5min"
        case 300..<900: return "5-15min"
        case 900..<1800: return "15-30min"
        default: return ">30min"
        }
    }

    /// Clasifica la longitud de un texto en rangos anonimizados.
    public static func bucketTextLength(_ length: Int) -> String {
        switch length {
        case ..<50: return "<50_chars"
        case 50..<200: return "50-200_chars"
        case 200..<1000: return "200-1000_chars"
        default: return ">1000_chars"
        }
    }
}
