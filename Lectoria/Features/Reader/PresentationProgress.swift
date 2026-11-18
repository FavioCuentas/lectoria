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
