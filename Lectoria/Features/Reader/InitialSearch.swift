import Foundation

// MARK: - InitialSearch

/// Búsqueda con la que se abre un lector desde la búsqueda global: el lector ejecuta su propia
/// búsqueda de `query` y se coloca en la primera coincidencia dentro de `scope`
/// (página, `href` de capítulo, bloque o diapositiva).
struct InitialSearch: Equatable, Sendable {
    let query: String
    let scope: String?
}

// MARK: - InitialSearchResolver

enum InitialSearchResolver {
    /// Primera coincidencia cuyo ámbito es `scope`; si no hay ninguna ahí, la primera del
    /// documento (para no abrir nunca con una barra "0 de 0"); `nil` si no hay coincidencias.
    static func firstMatchIndex<T>(in matches: [T], scope: String?, scopeOf: (T) -> String) -> Int? {
        guard !matches.isEmpty else { return nil }
        if let scope, let index = matches.firstIndex(where: { scopeOf($0) == scope }) {
            return index
        }
        return 0
    }

    /// Para texto: el primer resultado en el bloque indicado o después; si no hay, el primero.
    static func firstIndex<T>(in matches: [T], atOrAfter block: Int, blockOf: (T) -> Int) -> Int? {
        guard !matches.isEmpty else { return nil }
        return matches.firstIndex { blockOf($0) >= block } ?? 0
    }
}
