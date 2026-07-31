import Testing
import Foundation
import CoreGraphics
@testable import Lectoria

struct PresentationTextSelectionTests {

    @Test func testPresentationAnnotationModelInitialization() async throws {
        let docID = UUID().uuidString
        let geom = SelectionGeometry(x: 10, y: 20, width: 200, height: 40)
        let annotation = PresentationAnnotation(
            documentID: docID,
            slideID: "slide_1",
            slideIndex: 0,
            selectedText: "Arquitectura limpia en iOS",
            sourceType: .realText,
            selectionGeometry: geom,
            categoryID: "Definición",
            userComment: "Concepto clave para examen"
        )

        #expect(annotation.documentID == docID)
        #expect(annotation.slideIndex == 0)
        #expect(annotation.selectedText == "Arquitectura limpia en iOS")
        #expect(annotation.categoryID == "Definición")
        #expect(annotation.userComment == "Concepto clave para examen")
        #expect(annotation.selectionGeometry?.width == 200)
    }

    @Test func testSelectionGeometryRectConversion() async throws {
        let originalRect = CGRect(x: 15, y: 30, width: 120, height: 50)
        let geom = SelectionGeometry(rect: originalRect)

        #expect(geom.cgRect.origin.x == 15)
        #expect(geom.cgRect.origin.y == 30)
        #expect(geom.cgRect.size.width == 120)
        #expect(geom.cgRect.size.height == 50)
    }

    @Test func testAnnotationStudyCategoryMapping() async throws {
        let categories = StudyCategory.allCases.map { $0.rawValue }
        #expect(categories.contains("Importante"))
        #expect(categories.contains("Definición"))
        #expect(categories.contains("Ejemplo"))
        #expect(categories.contains("Duda"))
        #expect(categories.contains("Estudio"))
    }
}
