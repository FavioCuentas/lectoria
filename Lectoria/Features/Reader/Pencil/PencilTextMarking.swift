import Foundation
import CoreGraphics

// MARK: - PencilTextMarking

/// Lógica pura del marcador y el borrador del Pencil en EPUB y texto.
enum PencilTextMarking {
    /// Bloques (párrafos) cuyo marco se solapa en vertical con el trazo, en orden.
    /// Con `visible`, solo cuentan esos: los marcos de filas que salieron de pantalla pueden estar viejos.
    static func blocks(crossedBy span: ClosedRange<CGFloat>, frames: [Int: CGRect], visible: Set<Int>? = nil) -> [Int] {
        frames
            .filter { index, frame in
                (visible?.contains(index) ?? true) && frame.maxY >= span.lowerBound && frame.minY <= span.upperBound
            }
            .map(\.key)
            .sorted()
    }

    /// Ids que devuelve la página del EPUB (subrayados cuyo rango toca el trazo del borrador),
    /// limitados a los destacados de este documento y sin repetir.
    static func erasableIDs(from rawIDs: [String], highlights: [Highlight]) -> [UUID] {
        let known = Set(highlights.map(\.id))
        var seen: Set<UUID> = []
        return rawIDs.compactMap(UUID.init(uuidString:)).filter { known.contains($0) && seen.insert($0).inserted }
    }
}
