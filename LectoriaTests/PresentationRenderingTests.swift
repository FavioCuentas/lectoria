import Testing
import Foundation
import PDFKit
import UIKit
import SwiftUI
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

    /// Notas enlazadas por relación (no por número de archivo) y orden según `sldIdLst`:
    /// Alfa (con nota), Beta (sin nota), Gamma (con nota en notesSlide2), presentadas como Gamma, Alfa, Beta.
    @Test func testVisibleSlidesFollowsPresentationOrderAndNotesRelationships() async throws {
        let source = try #require(Bundle(for: FixtureBundleToken.self).url(forResource: "notes-reordered", withExtension: "pptx"))
        let slides = try await PPTXParser.visibleSlides(url: source)
        #expect(slides.map(\.title) == ["Gamma", "Alfa", "Beta"])
        #expect(slides.map(\.speakerNotes) == ["nota de Gamma", "nota de Alfa", nil])
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

    // MARK: - PresentationRenderingService

    /// Conversión falsa: cuenta llamadas y, si `fails` es falso, escribe un PDF de una página.
    @MainActor final class FakeConversion {
        var calls = 0
        var fails = false
        var delay: Duration = .zero
        func convert(_ source: URL, _ count: Int, _ destination: URL) async throws {
            calls += 1
            if delay > .zero { try await Task.sleep(for: delay) }
            if fails { throw PresentationConversionError.timedOut }
            try PresentationRenderingTests.makePDF(pages: ["ok"]).write(to: destination)
        }
    }

    private func makeService(_ fake: FakeConversion, dir: URL) -> PresentationRenderingService {
        PresentationRenderingService(
            directory: { dir },
            convert: { try await fake.convert($0, $1, $2) },
            slideCount: { _ in 1 }
        )
    }

    @Test func testEnsureRenderedSkipsWhenValidPDFExists() async throws {
        let dir = try tempDirectory()
        try Self.makePDF(pages: ["ya"]).write(to: RenderedPresentationStore.renderedURL(forLocalFileName: "a.pptx", in: dir))
        let fake = FakeConversion()
        await makeService(fake, dir: dir).ensureRendered(localFileName: "a.pptx", publicationID: UUID())
        #expect(fake.calls == 0)
    }

    @Test func testEnsureRenderedConvertsOncePerSessionOnFailure() async throws {
        let dir = try tempDirectory()
        let fake = FakeConversion()
        fake.fails = true
        let service = makeService(fake, dir: dir)
        let id = UUID()
        await service.ensureRendered(localFileName: "a.pptx", publicationID: id)
        await service.ensureRendered(localFileName: "a.pptx", publicationID: id)
        #expect(fake.calls == 1)
        #expect(!FileManager.default.fileExists(atPath: RenderedPresentationStore.renderedURL(forLocalFileName: "a.pptx", in: dir).path))
    }

    @Test func testConcurrentEnsureRenderedRunsOneConversion() async throws {
        let dir = try tempDirectory()
        let fake = FakeConversion()
        fake.delay = .milliseconds(100)
        let service = makeService(fake, dir: dir)
        let id = UUID()
        async let first: Void = service.ensureRendered(localFileName: "a.pptx", publicationID: id)
        async let second: Void = service.ensureRendered(localFileName: "a.pptx", publicationID: id)
        _ = await (first, second)
        #expect(fake.calls == 1)
    }

    @Test func testEnsureRenderedReplacesUnreadableFile() async throws {
        let dir = try tempDirectory()
        try Data("roto".utf8).write(to: RenderedPresentationStore.renderedURL(forLocalFileName: "a.pptx", in: dir))
        let fake = FakeConversion()
        await makeService(fake, dir: dir).ensureRendered(localFileName: "a.pptx", publicationID: UUID())
        #expect(fake.calls == 1)
        #expect(RenderedPresentationStore.validDocument(at: RenderedPresentationStore.renderedURL(forLocalFileName: "a.pptx", in: dir)) != nil)
    }

    @Test func testEnsureRenderedIgnoresLegacyFormats() async throws {
        let dir = try tempDirectory()
        let fake = FakeConversion()
        await makeService(fake, dir: dir).ensureRendered(localFileName: "x.ppt", publicationID: UUID())
        #expect(fake.calls == 0)
    }

    // MARK: - PresentationProgress

    @Test func testResumeIndexClamps() {
        #expect(PresentationProgress.resumeIndex(savedPageNumber: 12, totalSlides: 10) == 9)
        #expect(PresentationProgress.resumeIndex(savedPageNumber: nil, totalSlides: 10) == 0)
        #expect(PresentationProgress.resumeIndex(savedPageNumber: 0, totalSlides: 10) == 0)
        #expect(PresentationProgress.resumeIndex(savedPageNumber: 3, totalSlides: 0) == 0)
        #expect(PresentationProgress.resumeIndex(savedPageNumber: 3, totalSlides: 10) == 2)
    }

    @Test func testPercentage() {
        #expect(PresentationProgress.percentage(slideIndex: 0, totalSlides: 1) == 0)
        #expect(PresentationProgress.percentage(slideIndex: 4, totalSlides: 5) == 1)
        #expect(PresentationProgress.percentage(slideIndex: 2, totalSlides: 5) == 0.5)
        #expect(PresentationProgress.percentage(slideIndex: 9, totalSlides: 5) == 1)
    }

    /// Reanudar en la diapositiva guardada: el primer aviso de cambio de página de PDFKit
    /// (al maquetar) no debe devolver el índice a 0 y pisar el progreso.
    @Test func testWrapperKeepsResumedPageAfterLayout() async throws {
        let document = try #require(PDFDocument(data: Self.makePDF(pages: ["1", "2", "3", "4", "5"])))
        final class Box { var index = 3 }
        let box = Box()
        let wrapper = PDFPresentationPreviewWrapper(
            pdfDocument: document,
            pageIndex: Binding(get: { box.index }, set: { box.index = $0 }),
            annotations: [],
            onTextSelected: nil, onSelectionCleared: nil, onAddNoteRequest: nil, onTranslateRequest: nil
        )
        let coordinator = wrapper.makeCoordinator()
        let pdfView = wrapper.makeConfiguredView(coordinator: coordinator)

        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 300)
        pdfView.frame = window.bounds
        window.addSubview(pdfView)
        window.isHidden = false
        defer { window.isHidden = true }
        window.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(600))
        wrapper.applyUpdates(to: pdfView, coordinator: coordinator)
        try await Task.sleep(for: .milliseconds(300))

        #expect(box.index == 3)
        #expect(pdfView.currentPage.map { document.index(for: $0) } == 3)
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
