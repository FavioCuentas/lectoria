import SwiftUI
import PDFKit

// MARK: - PDFSearchMatch

/// Una coincidencia de búsqueda dentro del PDF, conservando la `PDFSelection` original
/// para poder sombrearla y navegar exactamente a su posición.
struct PDFSearchMatch: Identifiable {
    let id = UUID()
    let selection: PDFSelection
    let pageIndex: Int
    let pageTitle: String
    /// Fragmento con contexto alrededor de la coincidencia, con la palabra en negrita.
    let snippet: AttributedString
}

// MARK: - PDFTextSearch

@MainActor
enum PDFTextSearch {
    /// Máximo de coincidencias que se listan (evita bloqueos en documentos enormes).
    static let maxMatches = 1000

    /// Color de sombreado para todas las coincidencias y para la activa.
    static let matchColor = UIColor.systemYellow.withAlphaComponent(0.55)
    static let activeMatchColor = UIColor.systemOrange.withAlphaComponent(0.75)

    /// Busca `query` (sin distinguir mayúsculas ni acentos) en todo el documento.
    /// - Parameter pageLabel: título de cada resultado a partir del índice de página.
    ///   Por defecto "Página N" (o la etiqueta del PDF); las presentaciones usan "Diapositiva N".
    static func search(
        _ query: String,
        in document: PDFDocument,
        pageLabel: ((Int) -> String)? = nil
    ) -> [PDFSearchMatch] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let selections = document.findString(trimmed, withOptions: [.caseInsensitive, .diacriticInsensitive])
        var matches: [PDFSearchMatch] = []
        matches.reserveCapacity(min(selections.count, maxMatches))

        for selection in selections.prefix(maxMatches) {
            guard let page = selection.pages.first else { continue }
            let pageIndex = document.index(for: page)
            let pageTitle = pageLabel?(pageIndex) ?? "Página \(page.label ?? "\(pageIndex + 1)")"
            matches.append(PDFSearchMatch(
                selection: selection,
                pageIndex: pageIndex,
                pageTitle: pageTitle,
                snippet: snippet(for: selection, query: trimmed)
            ))
        }
        return matches
    }

    /// Número de páginas distintas con al menos una coincidencia.
    static func pageCount(of matches: [PDFSearchMatch]) -> Int {
        Set(matches.map(\.pageIndex)).count
    }

    /// Sombrea todas las coincidencias y resalta con otro color la activa.
    static func applyHighlights(_ matches: [PDFSearchMatch], activeIndex: Int?, on pdfView: PDFView) {
        pdfView.highlightedSelections = matches.enumerated().map { index, match in
            let copy = match.selection.copy() as? PDFSelection ?? match.selection
            copy.color = index == activeIndex ? activeMatchColor : matchColor
            return copy
        }
    }

    /// Quita el sombreado de búsqueda.
    static func clearHighlights(on pdfView: PDFView) {
        pdfView.highlightedSelections = nil
    }

    /// Lleva el PDFView a la coincidencia indicada (página + posición en modo continuo).
    static func go(to match: PDFSearchMatch, on pdfView: PDFView) {
        guard let page = match.selection.pages.first else { return }
        if pdfView.displayMode == .singlePageContinuous {
            // Deja algo de margen superior para que la palabra no quede pegada al borde.
            var rect = match.selection.bounds(for: page)
            rect = rect.insetBy(dx: 0, dy: -60)
            pdfView.go(to: rect, on: page)
        } else {
            pdfView.go(to: page)
        }
    }

    // MARK: - Private

    private static func snippet(for selection: PDFSelection, query: String) -> AttributedString {
        let context = selection.copy() as? PDFSelection ?? selection
        context.extend(atStart: 40)
        context.extend(atEnd: 60)

        let raw = (context.string ?? selection.string ?? query)
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)

        var attributed = AttributedString(raw)
        if let range = attributed.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) {
            attributed[range].inlinePresentationIntent = .stronglyEmphasized
        }
        return attributed
    }
}

// MARK: - ReaderSearchNavigatorBar

/// Barra flotante tras elegir un resultado: muestra "3 de 12" y permite ir a la coincidencia
/// anterior/siguiente, volver a la lista o cerrar la búsqueda.
struct ReaderSearchNavigatorBar: View {
    let query: String
    let activeIndex: Int
    let total: Int
    let theme: AppTheme
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onShowList: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Button(action: onShowList) {
                HStack(spacing: AppSpacing.xxs) {
                    Image(systemName: "magnifyingglass")
                    Text("\"\(query)\"")
                        .lineLimit(1)
                    Text("\(activeIndex + 1) de \(total)")
                        .monospacedDigit()
                        .foregroundStyle(AppColor.textSecondary(for: theme))
                }
                .font(AppTypography.footnote.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary(for: theme))
            }
            .accessibilityLabel("Coincidencia \(activeIndex + 1) de \(total). Ver lista de resultados")

            Spacer(minLength: AppSpacing.xs)

            Button(action: onPrevious) {
                Image(systemName: "chevron.up").padding(AppSpacing.xs)
            }
            .disabled(total < 2)
            .accessibilityLabel("Coincidencia anterior")

            Button(action: onNext) {
                Image(systemName: "chevron.down").padding(AppSpacing.xs)
            }
            .disabled(total < 2)
            .accessibilityLabel("Coincidencia siguiente")

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(AppColor.textTertiary(for: theme))
                    .padding(AppSpacing.xs)
            }
            .accessibilityLabel("Cerrar búsqueda")
        }
        .font(.body.weight(.semibold))
        .foregroundStyle(AppColor.accent(for: theme))
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xs)
        .background(.regularMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        .padding(.horizontal, AppSpacing.lg)
    }
}
