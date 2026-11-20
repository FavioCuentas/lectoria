import Testing
import Foundation
import CoreGraphics
@testable import Lectoria

struct PencilTextMarkingTests {
    private let frames: [Int: CGRect] = [
        0: CGRect(x: 0, y: 0, width: 300, height: 40),
        1: CGRect(x: 0, y: 50, width: 300, height: 80),
        2: CGRect(x: 0, y: 140, width: 300, height: 40),
    ]

    @Test func testBlocksCrossedByStroke() {
        #expect(PencilTextMarking.blocks(crossedBy: 60...70, frames: frames) == [1])
        #expect(PencilTextMarking.blocks(crossedBy: 30...150, frames: frames) == [0, 1, 2])
        #expect(PencilTextMarking.blocks(crossedBy: 42...48, frames: frames).isEmpty)
    }

    /// El borrador del EPUB recibe de la página los ids de los subrayados que toca el trazo:
    /// solo se borran los que existen en este documento.
    @Test func testErasableIDsKeepsOnlyKnownHighlights() {
        let a = Highlight(publicationID: UUID(), anchor: "{}", selectedText: "uno")
        let b = Highlight(publicationID: UUID(), anchor: "{}", selectedText: "dos")
        let ids = PencilTextMarking.erasableIDs(
            from: [b.id.uuidString, "no-es-un-uuid", UUID().uuidString, b.id.uuidString],
            highlights: [a, b]
        )
        #expect(ids == [b.id])
    }

    /// Solo cuentan los párrafos visibles: los marcos viejos de filas fuera de pantalla se ignoran.
    @Test func testBlocksIgnoreFramesOfHiddenRows() {
        let stale: [Int: CGRect] = [0: CGRect(x: 0, y: 0, width: 300, height: 40),
                                    80: CGRect(x: 0, y: 10, width: 300, height: 40)]
        #expect(PencilTextMarking.blocks(crossedBy: 5...20, frames: stale, visible: [0]) == [0])
    }
}
