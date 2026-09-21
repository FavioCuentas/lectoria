import Testing
import Foundation
@testable import Lectoria

@MainActor
struct PastedTextCoordinationTests {

    private func makeSamplePublication() -> PublicationRecord {
        PublicationRecord(
            id: UUID(),
            title: "Texto de prueba",
            publicationType: .pastedText,
            localFileName: "sample.txt",
            mimeType: "text/plain",
            fileSize: 100,
            sha256: "dummy-hash"
        )
    }

    @Test func testSuccessfulSaveGeneratesExactlyOneNavigationAfterDismissal() async throws {
        let router = AppRouter()
        let sample = makeSamplePublication()
        router.selectedTab = .home
        router.selectedPublication = nil

        // Simular guardado exitoso: se registra la publicación creada
        router.pendingCreatedPublication = sample
        #expect(router.selectedTab == .home)
        #expect(router.selectedPublication == nil)

        // Se produce el onDismiss del sheet
        router.handleNewTextDismissal()

        // Debe navegar a biblioteca y seleccionar la publicación
        #expect(router.selectedTab == .library)
        #expect(router.selectedPublication?.id == sample.id)
        #expect(router.pendingCreatedPublication == nil)
    }

    @Test func testManualDismissalDoesNotNavigate() async throws {
        let router = AppRouter()
        router.selectedTab = .home
        router.selectedPublication = nil
        router.pendingCreatedPublication = nil

        // Descarte manual (el usuario canceló sin guardar)
        router.handleNewTextDismissal()

        // El estado de navegación debe permanecer inalterado
        #expect(router.selectedTab == .home)
        #expect(router.selectedPublication == nil)
        #expect(router.pendingCreatedPublication == nil)
    }

    @Test func testTwoDismissalCallbacksDoNotGenerateDoubleNavigation() async throws {
        let router = AppRouter()
        let sample = makeSamplePublication()
        router.selectedTab = .home
        router.selectedPublication = nil
        router.pendingCreatedPublication = sample

        // Primer callback de cierre (consume la navegación)
        router.handleNewTextDismissal()
        #expect(router.selectedTab == .library)
        #expect(router.selectedPublication?.id == sample.id)
        #expect(router.pendingCreatedPublication == nil)

        // El usuario sale de la lectura y vuelve a home
        router.selectedTab = .home
        router.selectedPublication = nil

        // Un segundo callback espurio de onDismiss no debe re-navegar
        router.handleNewTextDismissal()
        #expect(router.selectedTab == .home)
        #expect(router.selectedPublication == nil)
        #expect(router.pendingCreatedPublication == nil)
    }

    @Test func testSaveErrorLeavesNoPendingNavigation() async throws {
        let router = AppRouter()
        router.selectedTab = .home
        router.selectedPublication = nil
        router.pendingCreatedPublication = nil

        // Simular que ocurrió un error: pendingCreatedPublication no se asigna
        #expect(router.pendingCreatedPublication == nil)

        // El sheet se cierra tras el error
        router.handleNewTextDismissal()

        #expect(router.selectedTab == .home)
        #expect(router.selectedPublication == nil)
        #expect(router.pendingCreatedPublication == nil)
    }

    @Test func testDoubleTapImportAndNewTextProtection() async throws {
        let router = AppRouter()

        #expect(router.isShowingImport == false)
        router.showImport()
        #expect(router.isShowingImport == true)
        // Segundo tap inmediato no duplica el estado
        router.showImport()
        #expect(router.isShowingImport == true)

        #expect(router.isShowingNewText == false)
        router.showNewText()
        #expect(router.isShowingNewText == true)
        // Segundo tap inmediato no duplica el estado
        router.showNewText()
        #expect(router.isShowingNewText == true)
    }
}
