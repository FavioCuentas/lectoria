import Testing
import Foundation
import PDFKit
import UIKit
@testable import Lectoria

struct PresentationSearchTests {

    @Test func testSearchEngineSlideTextMatching() async throws {
        let slideTexts: [Int: String] = [
            0: "Modelos Físicos de Datos y Arquitectura de Sistemas",
            1: "P&L Programa Médicos y Cifras Financieras",
            2: "Conclusiones y Próximos Pasos"
        ]

        let engine = PresentationSearchEngine(slideTexts: slideTexts)
        let results = engine.search(query: "Arquitectura")

        #expect(results.count == 1)
        #expect(results.first?.slideIndex == 0)
        #expect(results.first?.isPresenterNote == false)
        #expect(results.first?.matchSnippet.contains("Arquitectura") == true)
    }

    @Test func testSearchEnginePresenterNotesMatching() async throws {
        let slideTexts: [Int: String] = [
            0: "Diapositiva de Introducción"
        ]
        let presenterNotes: [Int: String] = [
            0: "Explicar al auditorio la importancia del presupuesto anual."
        ]

        let engine = PresentationSearchEngine(slideTexts: slideTexts, presenterNotes: presenterNotes)
        let results = engine.search(query: "presupuesto")

        #expect(results.count == 1)
        #expect(results.first?.slideIndex == 0)
        #expect(results.first?.isPresenterNote == true)
    }

    @Test func testEmptySearchQueryReturnsEmptyResults() async throws {
        let slideTexts: [Int: String] = [0: "Contenido de prueba"]
        let engine = PresentationSearchEngine(slideTexts: slideTexts)

        #expect(engine.search(query: "").isEmpty)
        #expect(engine.search(query: "   ").isEmpty)
    }

    @Test func testSearchEngineIgnoresAccents() {
        let engine = PresentationSearchEngine(
            slideTexts: [0: "Análisis del presupuesto"],
            presenterNotes: [1: "REVISIÓN final del plan"]
        )
        #expect(engine.search(query: "analisis").count == 1)
        let notes = engine.search(query: "revision")
        #expect(notes.count == 1)
        #expect(notes.first?.isPresenterNote == true)
        #expect(notes.first?.slideIndex == 1)
    }

    @MainActor
    @Test func testPDFSearchUsesCustomPageLabel() throws {
        let data = PresentationRenderingTests.makePDF(pages: ["inicio", "hola mundo"])
        let document = try #require(PDFDocument(data: data))
        let matches = PDFTextSearch.search("hola", in: document, pageLabel: { "Diapositiva \($0 + 1)" })
        #expect(matches.first?.pageTitle == "Diapositiva 2")
        // Por defecto se mantiene "Página N" para el lector PDF.
        #expect(PDFTextSearch.search("hola", in: document).first?.pageTitle == "Página 2")
    }

    @Test func testSlideSummaryPluralization() {
        #expect(PresentationSearchText.slideSummary(matchCount: 1, slideCount: 1) == "1 coincidencia en 1 diapositiva")
        #expect(PresentationSearchText.slideSummary(matchCount: 5, slideCount: 3) == "5 coincidencias en 3 diapositivas")
    }
}
