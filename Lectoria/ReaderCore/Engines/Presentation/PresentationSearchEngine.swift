import Foundation

// MARK: - PresentationSearchResult

/// Resultado de búsqueda dentro de una presentación.
public struct PresentationSearchResult: Identifiable, Sendable, Hashable {
    public var id: String { "\(slideIndex)_\(matchSnippet)" }
    public let slideIndex: Int
    public let matchSnippet: String
    public let isPresenterNote: Bool

    public init(slideIndex: Int, matchSnippet: String, isPresenterNote: Bool = false) {
        self.slideIndex = slideIndex
        self.matchSnippet = matchSnippet
        self.isPresenterNote = isPresenterNote
    }
}

// MARK: - PresentationSearchEngine

/// Motor de búsqueda e indexación de texto por diapositivas y notas del presentador.
public struct PresentationSearchEngine: Sendable {
    public let slideTexts: [Int: String]
    public let presenterNotes: [Int: String]

    public init(slideTexts: [Int: String], presenterNotes: [Int: String] = [:]) {
        self.slideTexts = slideTexts
        self.presenterNotes = presenterNotes
    }

    /// Busca una palabra o frase dentro del contenido indexado de la presentación.
    public func search(query: String) -> [PresentationSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var results: [PresentationSearchResult] = []

        // 1. Buscar en el texto visible de los slides
        for (slideIndex, text) in slideTexts.sorted(by: { $0.key < $1.key }) {
            if Self.contains(text, trimmed) {
                let snippet = extractSnippet(from: text, matching: trimmed)
                results.append(PresentationSearchResult(slideIndex: slideIndex, matchSnippet: snippet, isPresenterNote: false))
            }
        }

        // 2. Buscar en las notas del presentador
        for (slideIndex, note) in presenterNotes.sorted(by: { $0.key < $1.key }) {
            if Self.contains(note, trimmed) {
                let snippet = extractSnippet(from: note, matching: trimmed)
                results.append(PresentationSearchResult(slideIndex: slideIndex, matchSnippet: snippet, isPresenterNote: true))
            }
        }

        return results
    }

    /// Sin distinguir mayúsculas ni acentos, como la búsqueda en PDF.
    private static let matchOptions: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

    private static func contains(_ text: String, _ query: String) -> Bool {
        text.range(of: query, options: matchOptions) != nil
    }

    private func extractSnippet(from text: String, matching query: String) -> String {
        guard let range = text.range(of: query, options: Self.matchOptions) else { return text }
        let startIndex = text.index(range.lowerBound, offsetBy: -20, limitedBy: text.startIndex) ?? text.startIndex
        let endIndex = text.index(range.upperBound, offsetBy: 40, limitedBy: text.endIndex) ?? text.endIndex
        return "..." + text[startIndex..<endIndex].replacingOccurrences(of: "\n", with: " ") + "..."
    }
}
