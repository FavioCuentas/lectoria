import Testing
import Foundation
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
}
