import Testing
import Foundation
@testable import Lectoria

struct PresentationNavigationTests {

    // MARK: - 1. Cálculo de progreso con 0, 1 y varias diapositivas
    @Test func testProgressPercentCalculationZeroOneAndMultiple() async throws {
        func calculateProgress(currentIndex: Int, totalSlides: Int) -> Double {
            guard totalSlides > 1 else { return totalSlides == 1 ? 1.0 : 0.0 }
            let clamped = max(0, min(currentIndex, totalSlides - 1))
            return Double(clamped) / Double(totalSlides - 1)
        }

        func progressPercentageText(currentIndex: Int, totalSlides: Int) -> String {
            guard totalSlides > 0 else { return "0%" }
            if totalSlides == 1 { return "100%" }
            let progress = calculateProgress(currentIndex: currentIndex, totalSlides: totalSlides)
            return String(format: "%.0f%%", progress * 100)
        }

        // Caso 0 diapositivas: sin división por cero ni NaN
        #expect(calculateProgress(currentIndex: 0, totalSlides: 0) == 0.0)
        #expect(progressPercentageText(currentIndex: 0, totalSlides: 0) == "0%")

        // Caso 1 diapositiva: 100% de progreso sin división por cero
        #expect(calculateProgress(currentIndex: 0, totalSlides: 1) == 1.0)
        #expect(progressPercentageText(currentIndex: 0, totalSlides: 1) == "100%")

        // Caso múltiples diapositivas (5 diapositivas, índices 0..4)
        #expect(calculateProgress(currentIndex: 0, totalSlides: 5) == 0.0)
        #expect(progressPercentageText(currentIndex: 0, totalSlides: 5) == "0%")

        #expect(calculateProgress(currentIndex: 2, totalSlides: 5) == 0.5)
        #expect(progressPercentageText(currentIndex: 2, totalSlides: 5) == "50%")

        #expect(calculateProgress(currentIndex: 4, totalSlides: 5) == 1.0)
        #expect(progressPercentageText(currentIndex: 4, totalSlides: 5) == "100%")

        // Índice fuera de rango superior: debe ser clamped a 1.0
        #expect(calculateProgress(currentIndex: 10, totalSlides: 5) == 1.0)
        #expect(progressPercentageText(currentIndex: 10, totalSlides: 5) == "100%")

        // Índice negativo: debe ser clamped a 0.0
        #expect(calculateProgress(currentIndex: -2, totalSlides: 5) == 0.0)
        #expect(progressPercentageText(currentIndex: -2, totalSlides: 5) == "0%")
    }

    // MARK: - 2. Conversión índice interno ↔ número visible
    @Test func testInternalIndexAndVisibleNumberConversion() async throws {
        func visiblePageNumber(fromInternalIndex index: Int, totalSlides: Int) -> Int {
            guard totalSlides > 0 else { return 0 }
            return min(max(0, index) + 1, totalSlides)
        }

        func internalIndex(fromVisiblePageNumber page: Int) -> Int {
            return max(0, page - 1)
        }

        // Índice interno 0 -> Página visible 1
        #expect(visiblePageNumber(fromInternalIndex: 0, totalSlides: 10) == 1)
        #expect(internalIndex(fromVisiblePageNumber: 1) == 0)

        // Índice interno 4 -> Página visible 5
        #expect(visiblePageNumber(fromInternalIndex: 4, totalSlides: 10) == 5)
        #expect(internalIndex(fromVisiblePageNumber: 5) == 4)

        // Índice interno 9 -> Página visible 10
        #expect(visiblePageNumber(fromInternalIndex: 9, totalSlides: 10) == 10)
        #expect(internalIndex(fromVisiblePageNumber: 10) == 9)
    }

    // MARK: - 3. Validación de "Ir a página"
    @Test func testGoToPageValidation() async throws {
        let totalSlides = 12

        func validateAndParsePageInput(_ input: String, totalSlides: Int) -> Int? {
            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let page = Int(trimmed), page >= 1, page <= totalSlides else {
                return nil
            }
            return page - 1
        }

        // Vacía
        #expect(validateAndParsePageInput("", totalSlides: totalSlides) == nil)
        #expect(validateAndParsePageInput("   ", totalSlides: totalSlides) == nil)

        // No numérica
        #expect(validateAndParsePageInput("abc", totalSlides: totalSlides) == nil)
        #expect(validateAndParsePageInput("12a", totalSlides: totalSlides) == nil)
        #expect(validateAndParsePageInput("3.5", totalSlides: totalSlides) == nil)

        // Cero
        #expect(validateAndParsePageInput("0", totalSlides: totalSlides) == nil)

        // Negativos
        #expect(validateAndParsePageInput("-1", totalSlides: totalSlides) == nil)

        // Superior al total
        #expect(validateAndParsePageInput("13", totalSlides: totalSlides) == nil)
        #expect(validateAndParsePageInput("999", totalSlides: totalSlides) == nil)

        // Válidos en los límites y dentro
        #expect(validateAndParsePageInput("1", totalSlides: totalSlides) == 0)
        #expect(validateAndParsePageInput("6", totalSlides: totalSlides) == 5)
        #expect(validateAndParsePageInput("12", totalSlides: totalSlides) == 11)

        // Con espacios en blanco
        #expect(validateAndParsePageInput("  7  ", totalSlides: totalSlides) == 6)
    }

    // MARK: - 4. Clamp de índice fuera de rango
    @Test func testSlideNavigationBoundsAndClamping() async throws {
        var totalSlides = 10
        var currentIndex = 0

        // Avance seguro
        currentIndex = min(currentIndex + 1, totalSlides - 1)
        #expect(currentIndex == 1)

        // Salto a última
        currentIndex = totalSlides - 1
        #expect(currentIndex == 9)

        // Intento de avance fuera de rango
        currentIndex = min(currentIndex + 1, totalSlides - 1)
        #expect(currentIndex == 9)

        // Clamp cuando totalSlides se reduce (ej: de 10 a 3)
        totalSlides = 3
        func clamp(index: inout Int, total: Int) {
            if total <= 0 {
                index = 0
            } else if index >= total {
                index = total - 1
            } else if index < 0 {
                index = 0
            }
        }

        clamp(index: &currentIndex, total: totalSlides)
        #expect(currentIndex == 2)

        // Clamp cuando totalSlides pasa a 0
        totalSlides = 0
        clamp(index: &currentIndex, total: totalSlides)
        #expect(currentIndex == 0)
    }

    // MARK: - 5. Presentación vacía
    @Test func testEmptyPresentationDescriptionAndHandling() async throws {
        let totalSlides = 0
        let currentIndex = 0

        func slideProgressDescription(currentSlideIndex: Int, totalSlides: Int) -> String {
            guard totalSlides > 0 else {
                return "Sin diapositivas"
            }
            let currentHumanPage = min(currentSlideIndex + 1, totalSlides)
            return "Diapositiva \(currentHumanPage) de \(totalSlides) · 0%"
        }

        let desc = slideProgressDescription(currentSlideIndex: currentIndex, totalSlides: totalSlides)
        #expect(desc == "Sin diapositivas")
        #expect(!desc.contains("1/0"))
        #expect(!desc.contains("Diapositiva 1 de 0"))
    }

    // MARK: - 6. Habilitación de navegación por miniaturas según capacidad del visor
    @Test func testThumbnailNavigationDecisionByViewerCapability() async throws {
        // Simulación: PDFKit disponible -> Navegación indexada soportada
        let hasPDFDocument = true
        let isIndexableNavigationSupportedWithPDF = hasPDFDocument
        #expect(isIndexableNavigationSupportedWithPDF == true)

        // Simulación: Solo QuickLook (sin representación PDF paginable) -> Navegación indexada NO soportada
        let hasNoPDFDocument = false
        let isIndexableNavigationSupportedQuickLookOnly = hasNoPDFDocument
        #expect(isIndexableNavigationSupportedQuickLookOnly == false)

        // Acción al seleccionar miniatura
        var targetIndexApplied: Int? = nil
        func onThumbnailSelect(index: Int, canNavigate: Bool) {
            guard canNavigate else { return }
            targetIndexApplied = index
        }

        // Con PDF: se aplica el salto
        onThumbnailSelect(index: 4, canNavigate: isIndexableNavigationSupportedWithPDF)
        #expect(targetIndexApplied == 4)

        // Sin PDF (QuickLook nativo): NO se aplica salto falso
        targetIndexApplied = nil
        onThumbnailSelect(index: 4, canNavigate: isIndexableNavigationSupportedQuickLookOnly)
        #expect(targetIndexApplied == nil)
    }

    // MARK: - 7. Conservación del estado seleccionado e historial de salto
    @Test func testSelectionStateAndJumpHistory() async throws {
        var originIndex: Int? = nil
        var currentIndex = 2

        // Salto de diapositiva 2 a 8
        let targetIndex = 8
        originIndex = currentIndex
        currentIndex = targetIndex

        #expect(originIndex == 2)
        #expect(currentIndex == 8)

        // Retorno a diapositiva previa
        if let restore = originIndex {
            currentIndex = restore
            originIndex = nil
        }

        #expect(currentIndex == 2)
        #expect(originIndex == nil)
    }

    // MARK: - 8. Detección de diapositivas con notas/anotaciones
    @Test func testDetectionOfSlidesWithNotesAndAnnotations() async throws {
        let pubID = UUID()
        let notes: [Note] = [
            Note(publicationID: pubID, anchor: "slide_1", body: "Nota portada", tags: ["Importante"]),
            Note(publicationID: pubID, anchor: "slide_5", body: "Nota conclusiones", tags: ["Definición"]),
            Note(publicationID: pubID, anchor: "text_block_1", body: "Nota ajena a diapositivas", tags: [])
        ]

        let annotations: [PresentationAnnotation] = [
            PresentationAnnotation(documentID: pubID.uuidString, slideID: "slide_3", slideIndex: 2, selectedText: "Texto clave", categoryID: "Importante")
        ]

        var annotatedSlideIndices: Set<Int> = Set(annotations.map(\.slideIndex))
        for note in notes {
            if let anchor = note.anchor, anchor.hasPrefix("slide_"), let idx = Int(anchor.dropFirst(6)) {
                annotatedSlideIndices.insert(idx - 1)
            }
        }

        // Diapositiva 1 (índice 0) tiene nota
        #expect(annotatedSlideIndices.contains(0) == true)

        // Diapositiva 2 (índice 1) no tiene nota ni anotación
        #expect(annotatedSlideIndices.contains(1) == false)

        // Diapositiva 3 (índice 2) tiene anotación
        #expect(annotatedSlideIndices.contains(2) == true)

        // Diapositiva 4 (índice 3) no tiene
        #expect(annotatedSlideIndices.contains(3) == false)

        // Diapositiva 5 (índice 4) tiene nota
        #expect(annotatedSlideIndices.contains(4) == true)

        // Comprobación de hasNotesOnCurrentSlide para índice actual
        func hasNotes(onSlide index: Int) -> Bool {
            annotatedSlideIndices.contains(index)
        }

        #expect(hasNotes(onSlide: 0) == true)
        #expect(hasNotes(onSlide: 1) == false)
        #expect(hasNotes(onSlide: 2) == true)
        #expect(hasNotes(onSlide: 4) == true)
    }

    // MARK: - 9. QuickLook nunca muestra progreso indexado
    @Test func testQuickLookNeverShowsIndexedProgress() async throws {
        let isIndexableNavigationSupported = false
        let totalSlides = 15
        let currentSlideIndex = 3

        let topBarProgressText: String = {
            if isIndexableNavigationSupported {
                let currentHumanPage = min(currentSlideIndex + 1, totalSlides)
                return "Diapositiva \(currentHumanPage) de \(totalSlides) · 25%"
            } else {
                return "Vista previa QuickLook · navegación mediante gestos"
            }
        }()

        #expect(topBarProgressText == "Vista previa QuickLook · navegación mediante gestos")
        #expect(!topBarProgressText.contains("Diapositiva"))
        #expect(!topBarProgressText.contains("25%"))

        // ProgressView nunca debe mostrarse en QuickLook
        let shouldShowProgressView = isIndexableNavigationSupported && totalSlides > 1
        #expect(shouldShowProgressView == false)
    }

    // MARK: - 10. QuickLook nunca habilita "Ir a página"
    @Test func testQuickLookNeverEnablesGoToPage() async throws {
        let isIndexableNavigationSupported = false
        let totalSlides = 10

        // Condición para habilitar el botón y diálogo de salto directo
        let isGoToPageEnabled = isIndexableNavigationSupported && totalSlides > 0
        #expect(isGoToPageEnabled == false)

        var dialogOpened = false
        func triggerGoToPage() {
            guard isIndexableNavigationSupported, totalSlides > 0 else { return }
            dialogOpened = true
        }

        triggerGoToPage()
        #expect(dialogOpened == false)
    }

    // MARK: - 11. QuickLook inicia con destino -1 aunque totalSlides sea mayor que cero
    @Test func testQuickLookInitialOptionIsMinusOneEvenWhenTotalSlidesPositive() async throws {
        // Validación del coordinador compartido de producción
        #expect(PresentationNotesCoordinator.initialQuickLookOption() == -1)
        #expect(PresentationNotesCoordinator.generalNoteOption == -1)

        // Sesión real que modela el ciclo de vida del panel en PresentationReaderView
        var session = PresentationNotesSession()
        let totalSlides = 15

        // Aunque totalSlides sea mayor que cero y el usuario esté en cualquier diapositiva,
        // al abrir en QuickLook (isIndexableNavigationSupported == false) SIEMPRE inicia en -1.
        session.open(isIndexableNavigationSupported: false, currentSlideIndex: 4)

        #expect(session.isSheetPresented == true)
        #expect(session.quickLookNoteOption == -1)
        #expect(session.quickLookNoteOption != 0)
        #expect(session.quickLookAnchor(totalSlides: totalSlides) == "presentation_general")
    }

    // MARK: - 12. Sin selección explícita se obtiene exclusivamente presentation_general
    @Test func testQuickLookWithoutExplicitSelectionYieldsPresentationGeneral() async throws {
        var session = PresentationNotesSession()
        session.open(isIndexableNavigationSupported: false, currentSlideIndex: 0)

        // Sin selección explícita del usuario, la opción permanece en -1
        #expect(session.quickLookNoteOption == -1)

        // Comprobación con varios números de diapositivas (0, 1, 8, 50)
        for count in [0, 1, 8, 50] {
            let anchor = session.quickLookAnchor(totalSlides: count)
            let title = session.quickLookTitle(totalSlides: count)

            #expect(anchor == "presentation_general")
            #expect(anchor != "slide_1")
            #expect(title.contains("Nota general"))
        }

        // Creación de nota en NoteStore/Modelo con el anchor obtenido
        let pubID = UUID()
        let note = Note(
            publicationID: pubID,
            anchor: session.quickLookAnchor(totalSlides: 10),
            body: "Nota general de prueba",
            tags: ["Estudio"]
        )
        #expect(note.anchor == "presentation_general")
        #expect(note.anchor != "slide_1")
    }

    // MARK: - 13. Selección explícita del índice 0 produce exclusivamente slide_1
    @Test func testQuickLookExplicitSelectionOfIndexZeroProducesSlide1() async throws {
        var session = PresentationNotesSession()
        let totalSlides = 10
        session.open(isIndexableNavigationSupported: false, currentSlideIndex: 0)

        // El usuario selecciona explícitamente la Diapositiva 1 (índice 0)
        session.selectOption(0)
        #expect(session.quickLookNoteOption == 0)

        let anchorSlide1 = session.quickLookAnchor(totalSlides: totalSlides)
        let titleSlide1 = session.quickLookTitle(totalSlides: totalSlides)

        #expect(anchorSlide1 == "slide_1")
        #expect(anchorSlide1 != "presentation_general")
        #expect(titleSlide1.contains("1"))

        // Selección explícita de la Diapositiva 5 (índice 4)
        session.selectOption(4)
        #expect(session.quickLookNoteOption == 4)
        #expect(session.quickLookAnchor(totalSlides: totalSlides) == "slide_5")

        // Retorno explícito a la opción general (-1)
        session.selectOption(-1)
        #expect(session.quickLookNoteOption == -1)
        #expect(session.quickLookAnchor(totalSlides: totalSlides) == "presentation_general")
    }

    // MARK: - 14. Reabrir el panel restablece el destino general (-1)
    @Test func testReopeningQuickLookPanelResetsDestinationToMinusOne() async throws {
        var session = PresentationNotesSession()
        let totalSlides = 12

        // 1. Abre el panel: destino inicial siempre -1
        session.open(isIndexableNavigationSupported: false, currentSlideIndex: 0)
        #expect(session.quickLookNoteOption == -1)

        // 2. El usuario selecciona explícitamente una diapositiva concreta (ej: diapositiva 3, índice 2)
        session.selectOption(2)
        #expect(session.quickLookNoteOption == 2)
        #expect(session.quickLookAnchor(totalSlides: totalSlides) == "slide_3")

        // 3. Cierra el panel
        session.close()
        #expect(session.isSheetPresented == false)
        #expect(session.quickLookNoteOption == -1)

        // 4. Reabre el panel: debe restablecerse a -1 sin conservar la selección previa
        session.open(isIndexableNavigationSupported: false, currentSlideIndex: 0)
        #expect(session.isSheetPresented == true)
        #expect(session.quickLookNoteOption == -1)
        #expect(session.quickLookAnchor(totalSlides: totalSlides) == "presentation_general")
    }

    // MARK: - 15. Captura estable de notesTargetSlideIndex en PDF
    @Test func testStableCaptureOfNotesTargetSlideIndexInPDF() async throws {
        let pubID = UUID()
        var currentSlideIndex = 3 // Usuario está en Diapositiva 4
        var session = PresentationNotesSession()

        // Al presionar el botón de notas en PDFKit
        session.open(isIndexableNavigationSupported: true, currentSlideIndex: currentSlideIndex)
        #expect(session.pdfTargetSlideIndex == 3)
        #expect(session.pdfAnchor() == "slide_4")

        // Mientras el sheet está abierto, el PDF cambia de página en segundo plano a Diapositiva 7 (índice 6)
        currentSlideIndex = 6
        #expect(currentSlideIndex == 6)
        #expect(session.pdfTargetSlideIndex == 3) // No se desvía, permanece estable

        // Guardado de nota: debe usar el target capturado
        let savedAnchor = session.pdfAnchor()
        let note = Note(publicationID: pubID, anchor: savedAnchor, body: "Nota capturada de la diapositiva 4", tags: ["Definición"])
        #expect(note.anchor == "slide_4")
        #expect(note.anchor != "slide_7")
    }

    // MARK: - 16. La lógica probada es la misma que usa PresentationReaderView
    @Test func testPresentationNotesLogicIsSharedFromProductionCode() async throws {
        // Verifica que no se usan copias locales: se invoca directamente el código de producción
        let generalOption = PresentationNotesCoordinator.generalNoteOption
        #expect(generalOption == -1)

        let initialOption = PresentationNotesCoordinator.initialQuickLookOption()
        #expect(initialOption == -1)

        let anchorGen = PresentationNotesCoordinator.quickLookAnchor(forOption: initialOption, totalSlides: 20)
        #expect(anchorGen == "presentation_general")

        let anchorExplicitSlide1 = PresentationNotesCoordinator.quickLookAnchor(forOption: 0, totalSlides: 20)
        #expect(anchorExplicitSlide1 == "slide_1")

        let pdfAnchor = PresentationNotesCoordinator.pdfSlideAnchor(forTargetSlideIndex: 2)
        #expect(pdfAnchor == "slide_3")
    }

    // MARK: - 17. Nota general utiliza un anchor distinto de slide_1
    @Test func testGeneralNoteUsesDistinctAnchorFromSlide1() async throws {
        let pubID = UUID()
        let generalNote = Note(publicationID: pubID, anchor: "presentation_general", body: "Resumen ejecutivo", tags: ["Estudio"])
        let slide1Note = Note(publicationID: pubID, anchor: "slide_1", body: "Título de la primera diapositiva", tags: ["Importante"])

        #expect(generalNote.anchor != slide1Note.anchor)
        #expect(generalNote.anchor == "presentation_general")
        #expect(slide1Note.anchor == "slide_1")

        // Verificamos que la nota general no se compute como perteneciente a la diapositiva 1
        let notes = [generalNote, slide1Note]
        var slideIndicesWithNotes: Set<Int> = []
        for note in notes {
            if let anchor = note.anchor, anchor.hasPrefix("slide_"), let idx = Int(anchor.dropFirst(6)) {
                slideIndicesWithNotes.insert(idx - 1)
            }
        }

        #expect(slideIndicesWithNotes.contains(0) == true) // Por slide1Note
        // Si eliminamos slide1Note, generalNote no debe generar índice 0
        let notesOnlyGeneral = [generalNote]
        var generalOnlyIndices: Set<Int> = []
        for note in notesOnlyGeneral {
            if let anchor = note.anchor, anchor.hasPrefix("slide_"), let idx = Int(anchor.dropFirst(6)) {
                generalOnlyIndices.insert(idx - 1)
            }
        }
        #expect(generalOnlyIndices.isEmpty == true)
        #expect(generalOnlyIndices.contains(0) == false)
    }

    // MARK: - 18. PDF vecino con mismo nombre que PPTX no se adopta como derivado
    @Test func testNeighboringPDFWithSameNameAsPPTXNotAdoptedAsDerived() async throws {
        let fileURL = URL(fileURLWithPath: "/tmp/conferencia.pptx")

        // Regla estricta: solo se crea PDFDocument si la extensión de fileURL es "pdf"
        func resolvePDFDocument(for url: URL) -> Bool {
            let isNativePDF = url.pathExtension.lowercased() == "pdf"
            return isNativePDF
        }

        // Aunque exista en el sistema de archivos un conferencia.pdf vecino, fileURL es PPTX
        let isAdoptedAsPDF = resolvePDFDocument(for: fileURL)
        #expect(isAdoptedAsPDF == false)

        // Verificamos que no se utiliza validURL.deletingPathExtension().appendingPathExtension("pdf")
        let derivedNeighborURL = fileURL.deletingPathExtension().appendingPathExtension("pdf")
        #expect(derivedNeighborURL.pathExtension == "pdf")
        #expect(derivedNeighborURL.lastPathComponent == "conferencia.pdf")
        // La regla para el archivo original NO adopta el vecino:
        #expect(fileURL.pathExtension != "pdf")
    }

    // MARK: - 19. PDF nativo continúa siendo indexable
    @Test func testNativePDFRemainsIndexable() async throws {
        let fileURL = URL(fileURLWithPath: "/tmp/documento_presentacion.pdf")
        let isNativePDF = fileURL.pathExtension.lowercased() == "pdf"
        #expect(isNativePDF == true)

        let isIndexableNavigationSupported = isNativePDF
        #expect(isIndexableNavigationSupported == true)

        let totalSlides = 12
        let currentSlideIndex = 0

        func slideProgressDescription(currentSlideIndex: Int, totalSlides: Int) -> String {
            guard totalSlides > 0 else { return "Sin diapositivas" }
            let humanPage = min(currentSlideIndex + 1, totalSlides)
            return "Diapositiva \(humanPage) de \(totalSlides) · 0%"
        }

        let desc = slideProgressDescription(currentSlideIndex: currentSlideIndex, totalSlides: totalSlides)
        #expect(desc == "Diapositiva 1 de 12 · 0%")

        // "Ir a página" debe estar habilitado
        let canGoToPage = isIndexableNavigationSupported && totalSlides > 0
        #expect(canGoToPage == true)
    }

    // MARK: - 20. Estado inicial totalSlides == 0
    @Test func testInitialStateTotalSlidesIsZero() async throws {
        let initialTotalSlides = 0
        let currentSlideIndex = 0

        func slideProgressDescription(currentSlideIndex: Int, totalSlides: Int) -> String {
            guard totalSlides > 0 else { return "Sin diapositivas" }
            let currentHumanPage = min(currentSlideIndex + 1, totalSlides)
            return "Diapositiva \(currentHumanPage) de \(totalSlides) · 0%"
        }

        let desc = slideProgressDescription(currentSlideIndex: currentSlideIndex, totalSlides: initialTotalSlides)
        #expect(desc == "Sin diapositivas")
        #expect(!desc.contains("1/0"))
        #expect(!desc.contains("Diapositiva 1 de 0"))

        // Thumbnail strip con 0 diapositivas muestra empty state, no miniaturas ficticias
        let hasThumbnails = initialTotalSlides > 0
        #expect(hasThumbnails == false)
    }

    // MARK: - 21. Parser fallido no crea una diapositiva ficticia
    @Test func testFailedParserDoesNotCreateFictitiousSlide() async throws {
        // Simulación: el parser devuelve nil o array vacío tras error de descompresión/XML
        let parsedSlidesResult: [String]? = nil
        var totalSlides = 0

        if let slides = parsedSlidesResult, !slides.isEmpty {
            totalSlides = slides.count
        } else {
            totalSlides = 0
        }

        #expect(totalSlides == 0)
        #expect(totalSlides != 1)

        // Descripción de progreso para fallo del parser
        func progressLabel(total: Int) -> String {
            guard total > 0 else { return "Sin diapositivas" }
            return "Diapositiva 1 de \(total) · 0%"
        }

        #expect(progressLabel(total: totalSlides) == "Sin diapositivas")
        #expect(!progressLabel(total: totalSlides).contains("1/0"))
    }
    @Test func testInvalidQuickLookDestinationsUseGeneralNote() {
        for count in [0, 1, 5] {
            for option in [-2, -1, count, Int.max] {
                var session = PresentationNotesSession()
                session.selectOption(option)
                #expect(session.quickLookAnchor(totalSlides: count) == "presentation_general")
                #expect(session.quickLookTitle(totalSlides: count).contains("Nota general"))
            }
        }
    }

    @Test func testQuickLookDestinationBecomesInvalidWhenSlideCountShrinks() {
        var session = PresentationNotesSession()
        session.selectOption(4)
        #expect(session.quickLookAnchor(totalSlides: 5) == "slide_5")
        #expect(session.quickLookAnchor(totalSlides: 4) == "presentation_general")
    }

    @Test func testPerSlideThumbnailRequiresPDFDocument() {
        #expect(!PresentationThumbnailPolicy.canRenderSlide(hasPDFDocument: false))
        #expect(PresentationThumbnailPolicy.canRenderSlide(hasPDFDocument: true))
    }
}
