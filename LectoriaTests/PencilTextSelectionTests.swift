import Testing
import UIKit
import PDFKit
@testable import Lectoria

@MainActor
struct PencilTextSelectionTests {
    /// La página solo referencia débilmente su documento: hay que conservarlo durante la prueba.
    private static var keepAlive: [PDFDocument] = []

    /// PDF de una página con dos líneas de texto en posiciones conocidas.
    private func makePage() throws -> PDFPage {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let data = renderer.pdfData { context in
            context.beginPage()
            let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 24)]
            ("Llamadme Ismael" as NSString).draw(at: CGPoint(x: 72, y: 100), withAttributes: attributes)
            ("Otra línea distinta" as NSString).draw(at: CGPoint(x: 72, y: 300), withAttributes: attributes)
        }
        let document = try #require(PDFDocument(data: data))
        Self.keepAlive.append(document)
        return try #require(document.page(at: 0))
    }

    private func bounds(of text: String, on page: PDFPage) throws -> CGRect {
        let document = try #require(page.document)
        let match = try #require(document.findString(text, withOptions: []).first)
        return match.bounds(for: page)
    }

    @Test func testStrokeOverLineSelectsIt() throws {
        let page = try makePage()
        let line = try bounds(of: "Llamadme Ismael", on: page)
        let selection = PencilTextSelection.selection(
            on: page,
            from: CGPoint(x: line.minX + 1, y: line.midY),
            to: CGPoint(x: line.maxX - 1, y: line.midY)
        )
        #expect(selection?.string?.trimmingCharacters(in: .whitespacesAndNewlines) == "Llamadme Ismael")
    }

    @Test func testStrokeStartingInMarginSelectsLine() throws {
        let page = try makePage()
        let line = try bounds(of: "Llamadme Ismael", on: page)
        let selection = PencilTextSelection.selection(
            on: page,
            from: CGPoint(x: line.minX - 30, y: line.midY),
            to: CGPoint(x: line.maxX + 30, y: line.midY)
        )
        #expect(selection?.string?.trimmingCharacters(in: .whitespacesAndNewlines) == "Llamadme Ismael")
    }

    @Test func testStrokeOnEmptyAreaReturnsNil() throws {
        let page = try makePage()
        let selection = PencilTextSelection.selection(on: page, from: CGPoint(x: 100, y: 150), to: CGPoint(x: 400, y: 150))
        #expect(selection == nil)
    }

    @Test func testPartialStrokeSelectsPartOfLine() throws {
        let page = try makePage()
        let word = try bounds(of: "Ismael", on: page)
        let selection = PencilTextSelection.selection(
            on: page,
            from: CGPoint(x: word.minX + 1, y: word.midY),
            to: CGPoint(x: word.maxX - 1, y: word.midY)
        )
        let text = selection?.string ?? ""
        #expect(text.contains("Ismael"))
        #expect(!text.contains("Llamadme"))
    }
}
