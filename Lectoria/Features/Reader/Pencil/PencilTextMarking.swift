import Foundation
import CoreGraphics
@preconcurrency import ReadiumShared

// MARK: - PencilTextMarking

/// Lógica pura del marcador y el borrador del Pencil en EPUB y texto.
enum PencilTextMarking {
    /// Bloques (párrafos) cuyo marco se solapa en vertical con el trazo, en orden.
    static func blocks(crossedBy span: ClosedRange<CGFloat>, frames: [Int: CGRect]) -> [Int] {
        frames
            .filter { _, frame in frame.maxY >= span.lowerBound && frame.minY <= span.upperBound }
            .map(\.key)
            .sorted()
    }

    /// Destacados del mismo capítulo (`href`) cuyo texto se solapa con el texto del trazo del borrador.
    static func highlightsToErase(_ highlights: [Highlight], strokeText: String, href: String) -> [UUID] {
        let stroke = normalize(strokeText)
        guard stroke.count >= 2 else { return [] }
        return highlights.compactMap { highlight in
            guard let locator = try? Locator(jsonString: highlight.anchor),
                  locator.href.string == href else { return nil }
            let text = normalize(highlight.selectedText)
            guard !text.isEmpty else { return nil }
            return (stroke.contains(text) || text.contains(stroke)) ? highlight.id : nil
        }
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}
