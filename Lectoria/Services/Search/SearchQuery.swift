import Foundation

// MARK: - SearchQuery

/// Convierte lo que escribe el usuario en una expresión FTS5 segura.
///
/// La consulta va como una frase entre comillas (las comillas internas se duplican), así que los
/// operadores de FTS5 (`*`, `-`, `OR`, `NEAR`, `(`, `:`) se buscan como texto y nunca rompen la
/// consulta. Es una frase porque los lectores buscan el texto literal: así todo resultado de la
/// Biblioteca se encuentra también al abrir el documento. La última palabra admite prefijo.
enum SearchQuery {
    static func ftsExpression(for userQuery: String) -> String? {
        let words = userQuery
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { word in word.contains { $0.isLetter || $0.isNumber } }
        guard !words.isEmpty else { return nil }
        // Una sola frase: las palabras juntas y en orden, como buscan los lectores.
        let phrase = words.joined(separator: " ").replacingOccurrences(of: "\"", with: "\"\"")
        return "\"" + phrase + "\"*"
    }
}
