import Testing
import Foundation
import PDFKit
import UIKit
@testable import Lectoria

@MainActor
struct PresentationRenderingTests {

    // MARK: - Helpers

    private func tempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rendering-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// PDF de `pages` páginas; cada página dibuja el texto indicado.
    static func makePDF(pages: [String]) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 400, height: 300))
        return renderer.pdfData { context in
            for text in pages {
                context.beginPage()
                (text as NSString).draw(at: CGPoint(x: 40, y: 40), withAttributes: [.font: UIFont.systemFont(ofSize: 24)])
            }
        }
    }

    // MARK: - RenderedPresentationStore

    @Test func testRenderedURLAppendsSuffix() {
        let url = RenderedPresentationStore.renderedURL(forLocalFileName: "ABC.pptx", in: URL(fileURLWithPath: "/x"))
        #expect(url.path == "/x/ABC.pptx.rendered.pdf")
    }

    @Test func testValidDocumentRejectsMissingAndGarbage() throws {
        let dir = try tempDirectory()
        #expect(RenderedPresentationStore.validDocument(at: dir.appendingPathComponent("missing.pdf")) == nil)
        let garbage = dir.appendingPathComponent("garbage.pdf")
        try Data("not a pdf".utf8).write(to: garbage)
        #expect(RenderedPresentationStore.validDocument(at: garbage) == nil)
    }

    @Test func testValidDocumentAcceptsOnePagePDF() throws {
        let dir = try tempDirectory()
        let url = dir.appendingPathComponent("one.pdf")
        try Self.makePDF(pages: ["hola"]).write(to: url)
        #expect(RenderedPresentationStore.validDocument(at: url)?.pageCount == 1)
    }

    // MARK: - PresentationPDFConverter (integración en dispositivo)

    /// Presentación de 3 diapositivas con cuadros de texto (python-pptx); la 3.ª está oculta
    /// (`show="0"`). WebKit no maqueta el zip mínimo de `SamplePPTXGenerator` ni las
    /// diapositivas con marcadores de posición de python-pptx (OfficeImport error 912).
    private func samplePPTX() throws -> (url: URL, dir: URL) {
        let source = try #require(Bundle(for: FixtureBundleToken.self).url(forResource: "three-slides-one-hidden", withExtension: "pptx"))
        let dir = try tempDirectory()
        let url = dir.appendingPathComponent("sample.pptx")
        try FileManager.default.copyItem(at: source, to: url)
        return (url, dir)
    }

    @Test func testVisibleSlidesSkipsHiddenSlides() async throws {
        let (pptx, _) = try samplePPTX()
        let slides = try await PPTXParser.visibleSlides(url: pptx)
        #expect(slides.map(\.title) == ["Análisis del presupuesto", "Conclusiones finales"])
    }

    @Test func testConvertWritesOnePagePerSlideWithSearchableText() async throws {
        let (pptx, dir) = try samplePPTX()
        let slides = try await PPTXParser.visibleSlides(url: pptx)
        let destination = RenderedPresentationStore.renderedURL(forLocalFileName: "sample.pptx", in: dir)

        try await PresentationPDFConverter().convert(pptxURL: pptx, expectedSlideCount: slides.count, destination: destination)

        let document = try #require(RenderedPresentationStore.validDocument(at: destination))
        #expect(document.pageCount == slides.count)
        let title = try #require(slides.first?.title)
        let text = document.string ?? ""
        #expect(text.range(of: title, options: [.caseInsensitive, .diacriticInsensitive]) != nil)
    }

    @Test func testConvertSlideCountMismatchWritesNothing() async throws {
        let (pptx, dir) = try samplePPTX()
        let slides = try await PPTXParser.visibleSlides(url: pptx)
        let destination = RenderedPresentationStore.renderedURL(forLocalFileName: "sample.pptx", in: dir)

        await #expect(throws: PresentationConversionError.self) {
            try await PresentationPDFConverter(timeout: .seconds(5))
                .convert(pptxURL: pptx, expectedSlideCount: slides.count + 3, destination: destination)
        }
        #expect(!FileManager.default.fileExists(atPath: destination.path))
    }

    @Test func testIsConvertibleOnlyPPTX() {
        #expect(RenderedPresentationStore.isConvertible(localFileName: "a.pptx"))
        #expect(RenderedPresentationStore.isConvertible(localFileName: "A.PPTX"))
        for name in ["a.ppt", "a.key", "a.odp", "a.pdf"] {
            #expect(!RenderedPresentationStore.isConvertible(localFileName: name))
        }
    }
}

final class FixtureBundleToken {}
