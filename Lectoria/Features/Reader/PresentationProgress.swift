import Foundation

// MARK: - PresentationProgress

/// Cálculos de progreso de una presentación en la ruta PDF (diapositiva actual / total).
enum PresentationProgress {
    /// Mismo criterio que el lector PDF: índice / (total - 1), entre 0 y 1.
    static func percentage(slideIndex: Int, totalSlides: Int) -> Double {
        let value = Double(slideIndex) / Double(max(1, totalSlides - 1))
        return min(1, max(0, value))
    }

    /// Diapositiva desde la que reanudar. Se ajusta al rango por si el PDF se regeneró
    /// con menos páginas que el progreso guardado.
    static func resumeIndex(savedPageNumber: Int?, totalSlides: Int) -> Int {
        guard let page = savedPageNumber, totalSlides > 0 else { return 0 }
        return min(max(0, page - 1), totalSlides - 1)
    }
}

// MARK: - PresentationSearchText

/// Textos de la búsqueda dentro de presentaciones.
enum PresentationSearchText {
    /// "1 coincidencia en 1 diapositiva" / "5 coincidencias en 3 diapositivas".
    static func slideSummary(matchCount: Int, slideCount: Int) -> String {
        let matches = matchCount == 1
            ? String(localized: "1 coincidencia", comment: "Presentation search: one match")
            : String(localized: "\(matchCount) coincidencias", comment: "Presentation search: N matches")
        let slides = slideCount == 1
            ? String(localized: "1 diapositiva", comment: "Presentation search: one slide")
            : String(localized: "\(slideCount) diapositivas", comment: "Presentation search: N slides")
        return String(localized: "\(matches) en \(slides)", comment: "Presentation search summary: matches in slides")
    }
}
