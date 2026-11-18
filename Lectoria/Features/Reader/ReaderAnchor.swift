import Foundation
@preconcurrency import ReadiumShared

// MARK: - ReaderAnchor

/// Convierte el `anchor` guardado en notas y destacados en una ubicación del lector.
enum ReaderAnchor {
    /// Los destacados de EPUB guardan el localizador de Readium tal cual (`Locator.jsonString()`),
    /// no un `EPUBLocation` codificado.
    static func epubLocation(from anchor: String?) -> EPUBLocation? {
        guard let anchor, let locator = try? Locator(jsonString: anchor) else { return nil }
        return EPUBLocation(locator: locator)
    }
}
