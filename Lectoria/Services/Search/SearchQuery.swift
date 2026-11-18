import Foundation

// MARK: - SearchQuery

/// Convierte lo que escribe el usuario en una expresión FTS5 segura.
///
/// Cada palabra va entre comillas (las comillas internas se duplican), así que los operadores
/// de FTS5 (`*`, `-`, `OR`, `NEAR`, `(`, `:`) se buscan como texto y nunca rompen la consulta.
/// La última palabra admite prefijo, para encontrar resultados mientras se escribe.
enum SearchQuery {
    static func ftsExpression(for userQuery: String) -> String? {
        let words = userQuery
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { word in word.contains { $0.isLetter || $0.isNumber } }
        guard !words.isEmpty else { return nil }
        let quoted = words.map { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        return quoted.joined(separator: " ") + "*"
    }
}
