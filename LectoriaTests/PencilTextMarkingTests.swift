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

    private func highlight(_ text: String, href: String) -> Highlight {
        let anchor = "{\"href\":\"\(href)\",\"type\":\"application/xhtml+xml\",\"locations\":{},\"text\":{\"highlight\":\"\(text)\"}}"
        return Highlight(publicationID: UUID(), anchor: anchor, selectedText: text)
    }

    @Test func testEraseOverlappingInSameChapterOnly() {
        let inside = highlight("la ballena blanca", href: "cap1.xhtml")
        let containing = highlight("Llamadme Ismael", href: "cap1.xhtml")
        let otherChapter = highlight("la ballena blanca", href: "cap2.xhtml")
        let unrelated = highlight("el faro", href: "cap1.xhtml")

        let erased = PencilTextMarking.highlightsToErase(
            [inside, containing, otherChapter, unrelated],
            strokeText: "vio  la Ballena blanca y",
            href: "cap1.xhtml"
        )
        #expect(Set(erased) == [inside.id])

        let erased2 = PencilTextMarking.highlightsToErase([containing], strokeText: "Ismael", href: "cap1.xhtml")
        #expect(erased2 == [containing.id])
    }

    @Test func testEmptyStrokeErasesNothing() {
        let h = highlight("a", href: "cap1.xhtml")
        #expect(PencilTextMarking.highlightsToErase([h], strokeText: " ", href: "cap1.xhtml").isEmpty)
        #expect(PencilTextMarking.highlightsToErase([h], strokeText: "a", href: "cap1.xhtml").isEmpty)
    }
}
