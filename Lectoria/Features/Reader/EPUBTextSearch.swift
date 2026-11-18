import SwiftUI
@preconcurrency import ReadiumShared
@preconcurrency import ReadiumNavigator

// MARK: - EPUBSearchMatch

/// Una coincidencia de búsqueda dentro del EPUB, con el `Locator` exacto de Readium
/// para sombrearla (decoraciones) y navegar a ella.
struct EPUBSearchMatch: Identifiable {
    let id: Int
    let locator: Locator
    /// Recurso (capítulo) al que pertenece; sirve para contar capítulos distintos.
    let chapterKey: String
    let chapterTitle: String
    /// Fragmento con contexto alrededor de la coincidencia, con la palabra en negrita.
    let snippet: AttributedString
}

// MARK: - EPUBTextSearch

@MainActor
enum EPUBTextSearch {
    /// Máximo de coincidencias que se listan (evita bloqueos en libros enormes).
    static let maxMatches = 1000

    /// Grupo de decoraciones de Readium, separado de los destacados del usuario.
    static let decorationGroup = "search"

    static let matchColor = UIColor.systemYellow.withAlphaComponent(0.55)
    static let activeMatchColor = UIColor.systemOrange.withAlphaComponent(0.75)

    /// Busca `query` en todo el libro (sin distinguir mayúsculas ni acentos)
    /// usando el servicio de búsqueda de contenido de Readium.
    static func search(_ query: String, in publication: Publication) async -> [EPUBSearchMatch] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, publication.isSearchable else { return [] }

        var options = SearchOptions()
        options.caseSensitive = false
        options.diacriticSensitive = false

        guard case .success(let iterator) = await publication.search(query: trimmed, options: options) else {
            return []
        }
        defer { iterator.close() }

        var locators: [Locator] = []
        while locators.count < maxMatches {
            guard case .success(let page) = await iterator.next(), let page else { break }
            locators.append(contentsOf: page.locators)
        }

        return locators.prefix(maxMatches).enumerated().map { index, locator in
            EPUBSearchMatch(
                id: index,
                locator: locator,
                chapterKey: locator.href.string,
                chapterTitle: locator.title ?? "Capítulo",
                snippet: snippet(for: locator)
            )
        }
    }

    /// Número de capítulos distintos con al menos una coincidencia.
    static func chapterCount(of matches: [EPUBSearchMatch]) -> Int {
        Set(matches.map(\.chapterKey)).count
    }

    /// Sombrea todas las coincidencias y resalta con otro color la activa.
    static func applyHighlights(_ matches: [EPUBSearchMatch], activeIndex: Int?, on navigator: EPUBNavigatorViewController) {
        let decorations = matches.map { match in
            Decoration(
                id: "search-\(match.id)",
                locator: match.locator,
                style: .highlight(tint: match.id == activeIndex ? activeMatchColor : matchColor)
            )
        }
        navigator.apply(decorations: decorations, in: decorationGroup)
    }

    /// Quita el sombreado de búsqueda.
    static func clearHighlights(on navigator: EPUBNavigatorViewController) {
        navigator.apply(decorations: [], in: decorationGroup)
    }

    // MARK: - Private

    private static func snippet(for locator: Locator) -> AttributedString {
        func clean(_ string: String?) -> String {
            (string ?? "").components(separatedBy: .newlines).joined(separator: " ")
        }
        let before = String(clean(locator.text.before).suffix(50))
        let highlight = clean(locator.text.highlight)
        let after = String(clean(locator.text.after).prefix(70))

        var result = AttributedString(before.trimmingCharacters(in: .whitespaces).isEmpty ? "" : "…" + before)
        var match = AttributedString(highlight)
        match.inlinePresentationIntent = .stronglyEmphasized
        result.append(match)
        result.append(AttributedString(after + (after.isEmpty ? "" : "…")))
        return result
    }
}
