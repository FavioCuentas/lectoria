import Testing
import Foundation
import CoreGraphics
@testable import Lectoria

struct PresentationAnnotationTests {

    @Test func testStudyCategoriesEnum() async throws {
        let categories = StudyCategory.allCases
        #expect(categories.count == 5)
        #expect(categories.contains(.importante))
        #expect(categories.contains(.definicion))
        #expect(categories.contains(.ejemplo))
        #expect(categories.contains(.duda))
        #expect(categories.contains(.estudio))
    }

    @Test func testSlideAnnotationPinNormalizedCoordinates() async throws {
        let pin = SlideAnnotationPin(
            slideIndex: 3,
            normalizedPoint: CGPoint(x: 0.4, y: 0.6),
            category: .definicion,
            noteText: "Definición clave de arquitectura"
        )

        #expect(pin.slideIndex == 3)
        #expect(pin.normalizedPoint.x == 0.4)
        #expect(pin.normalizedPoint.y == 0.6)
        #expect(pin.category == .definicion)
        #expect(pin.noteText == "Definición clave de arquitectura")
    }

    @Test func testSlideNoteFilteringByAnchor() async throws {
        let pubID = UUID()
        let notes = [
            Note(publicationID: pubID, anchor: "slide_1", body: "Nota del slide 1", tags: ["Importante"]),
            Note(publicationID: pubID, anchor: "slide_2", body: "Nota del slide 2", tags: ["Definición"]),
            Note(publicationID: pubID, anchor: "slide_1", body: "Segunda nota slide 1", tags: ["Duda"])
        ]

        let slide1Notes = notes.filter { $0.anchor == "slide_1" }
        let slide2Notes = notes.filter { $0.anchor == "slide_2" }
        let slide3Notes = notes.filter { $0.anchor == "slide_3" }

        #expect(slide1Notes.count == 2)
        #expect(slide2Notes.count == 1)
        #expect(slide3Notes.count == 0)
    }
}
