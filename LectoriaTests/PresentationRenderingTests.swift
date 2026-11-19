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

    @Test func testSecondCallerWaitsForInFlightConversion() async throws {
        let dir = try tempDirectory()
        let fake = FakeConversion()
        fake.delay = .milliseconds(200)
        let service = makeService(fake, dir: dir)
        let id = UUID()
        let destination = RenderedPresentationStore.renderedURL(forLocalFileName: "a.pptx", in: dir)
        let first = Task { await service.ensureRendered(localFileName: "a.pptx", publicationID: id) }
        try await Task.sleep(for: .milliseconds(20))
        // Quien abre la presentación mientras la importación aún convierte debe esperar el PDF.
        await service.ensureRendered(localFileName: "a.pptx", publicationID: id)
        #expect(RenderedPresentationStore.validDocument(at: destination) != nil)
        await first.value
        #expect(fake.calls == 1)
    }

    // MARK: - PresentationOpenRoute

    @Test func testOpenRouteUsesPDFReaderWhenRenderedExists() throws {
        let dir = try tempDirectory()
        try Self.makePDF(pages: ["x"]).write(to: RenderedPresentationStore.renderedURL(forLocalFileName: "a.pptx", in: dir))
        #expect(PresentationOpenRoute.decide(localFileName: "a.pptx", directory: dir) == .pdf(localFileName: "a.pptx.rendered.pdf"))
    }

    @Test func testOpenRouteConvertsPPTXWithoutPDF() throws {
        let dir = try tempDirectory()
        #expect(PresentationOpenRoute.decide(localFileName: "a.pptx", directory: dir) == .convert)
        try Data("roto".utf8).write(to: RenderedPresentationStore.renderedURL(forLocalFileName: "a.pptx", in: dir))
        #expect(PresentationOpenRoute.decide(localFileName: "a.pptx", directory: dir) == .convert)
    }

    @Test func testOpenRouteKeepsQuickLookForLegacyFormats() throws {
        let dir = try tempDirectory()
        #expect(PresentationOpenRoute.decide(localFileName: "a.ppt", directory: dir) == .presentation)
        #expect(PresentationOpenRoute.decide(localFileName: "a.key", directory: dir) == .presentation)
        #expect(PresentationOpenRoute.decide(localFileName: "a.pptx", directory: nil) == .presentation)
    }

    // MARK: - Registro de la presentación al abrirla como PDF

    @Test func testMarkOpenedKeepsStoredFileName() async throws {
        let repo = SwiftDataPublicationRepository(container: ModelContainerFactory.create(isStoredInMemoryOnly: true))
        let deck = PublicationRecord.newImport(title: "Deck", publicationType: .pptx, localFileName: "a.pptx",
                                               mimeType: "x", fileSize: 1, sha256: UUID().uuidString)
        try await repo.save(deck)
        // El lector de PDF trabaja con una copia que apunta al PDF convertido.
        await PublicationRecordUpdates.markOpened(deck.id, repository: repo)
        let stored = try #require(try await repo.fetch(id: deck.id))
        #expect(stored.localFileName == "a.pptx")
        #expect(stored.lastOpenedAt != nil)
    }

    @Test func testRepairRestoresPresentationFileNames() async throws {
        let repo = SwiftDataPublicationRepository(container: ModelContainerFactory.create(isStoredInMemoryOnly: true))
        var broken = PublicationRecord.newImport(title: "Deck", publicationType: .pptx, localFileName: "a.pptx",
                                                 mimeType: "x", fileSize: 1, sha256: UUID().uuidString)
        broken.localFileName = "a.pptx.rendered.pdf"
        broken.indexingStatus = .failed
        let pdf = PublicationRecord.newImport(title: "Doc", publicationType: .pdf, localFileName: "b.rendered.pdf",
                                              mimeType: "x", fileSize: 1, sha256: UUID().uuidString)
        try await repo.save(broken)
        try await repo.save(pdf)

        await PublicationRecordUpdates.repairPresentationFileNames(repository: repo)

        let fixed = try #require(try await repo.fetch(id: broken.id))
        #expect(fixed.localFileName == "a.pptx")
        #expect(fixed.indexingStatus == .pending)
        #expect(try await repo.fetch(id: pdf.id)?.localFileName == "b.rendered.pdf")
    }

    /// Presentaciones grandes (material de clase de 50+ diapositivas) necesitan más de 30 s.
    @Test func testOverallTimeoutScalesWithSlides() {
        #expect(PresentationPDFConverter.overallTimeout(forSlides: 10) == .seconds(30))
        #expect(PresentationPDFConverter.overallTimeout(forSlides: 100) == .seconds(110))
        #expect(PresentationPDFConverter.overallTimeout(forSlides: 1000) == .seconds(240))
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
