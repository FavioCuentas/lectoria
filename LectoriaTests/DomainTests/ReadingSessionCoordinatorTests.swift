import Testing
import Foundation
import SwiftUI
@testable import Lectoria

@MainActor
final class MockReadingSessionRepository: ReadingSessionRepository {
    var savedSessions: [ReadingSession] = []

    func fetch(forPublication publicationID: UUID) async throws -> [ReadingSession] {
        savedSessions.filter { $0.publicationID == publicationID }
    }

    func fetchAll() async throws -> [ReadingSession] {
        savedSessions
    }

    /// Upsert por `id`, igual que el repositorio real.
    func save(_ session: ReadingSession) async throws {
        if let index = savedSessions.firstIndex(where: { $0.id == session.id }) {
            savedSessions[index] = session
        } else {
            savedSessions.append(session)
        }
    }
}

@MainActor
struct ReadingSessionCoordinatorTests {

    @Test
    func testSessionStartsOnlyWhenExplicitlyStarted() async throws {
        let mockAnalytics = MockAnalyticsService()
        let mockRepo = MockReadingSessionRepository()
        let docID = UUID()

        let coordinator = ReadingSessionCoordinator(
            publicationID: docID,
            format: "pdf",
            analyticsService: mockAnalytics,
            readingSessionRepository: mockRepo
        )

        // Antes de iniciar
        #expect(!coordinator.isSessionActive)
        #expect(!coordinator.hasEnded)
        #expect(coordinator.currentActiveSeconds == 0)

        // Iniciar
        coordinator.startSession()
        #expect(coordinator.isSessionActive)
        #expect(!coordinator.hasEnded)
    }

    @Test
    func testActiveDurationAccumulation() async throws {
        let mockAnalytics = MockAnalyticsService()
        let baseInstant = ContinuousClock.now
        var currentInstant = baseInstant

        let coordinator = ReadingSessionCoordinator(
            publicationID: UUID(),
            format: "epub",
            analyticsService: mockAnalytics,
            nowProvider: { currentInstant }
        )

        coordinator.startSession()

        // Avanzar 15 segundos
        currentInstant = currentInstant.advanced(by: .seconds(15))
        #expect(coordinator.currentActiveSeconds == 15)

        // Avanzar 10 segundos más
        currentInstant = currentInstant.advanced(by: .seconds(10))
        #expect(coordinator.currentActiveSeconds == 25)
    }

    @Test
    func testPauseAndResumeExcludesBackgroundTime() async throws {
        let mockAnalytics = MockAnalyticsService()
        let baseInstant = ContinuousClock.now
        var currentInstant = baseInstant

        let coordinator = ReadingSessionCoordinator(
            publicationID: UUID(),
            format: "txt",
            analyticsService: mockAnalytics,
            nowProvider: { currentInstant }
        )

        coordinator.startSession()

        // 1. Activo durante 20 segundos
        currentInstant = currentInstant.advanced(by: .seconds(20))
        #expect(coordinator.currentActiveSeconds == 20)

        // 2. Pasa a segundo plano
        coordinator.handleScenePhaseChange(.background)

        // 3. Pasan 120 segundos en segundo plano
        currentInstant = currentInstant.advanced(by: .seconds(120))
        // El tiempo activo acumulado debe congelarse en 20
        #expect(coordinator.currentActiveSeconds == 20)

        // 4. Vuelve a primer plano (activo)
        coordinator.handleScenePhaseChange(.active)

        // 5. Lee otros 10 segundos
        currentInstant = currentInstant.advanced(by: .seconds(10))
        // El tiempo total debe ser 20 + 10 = 30 (los 120 de background se excluyeron)
        #expect(coordinator.currentActiveSeconds == 30)
    }

    @Test
    func testEndSessionIsIdempotentAndEmitsOnlyOnce() async throws {
        let mockAnalytics = MockAnalyticsService()
        let baseInstant = ContinuousClock.now
        var currentInstant = baseInstant

        let coordinator = ReadingSessionCoordinator(
            publicationID: UUID(),
            format: "markdown",
            analyticsService: mockAnalytics,
            nowProvider: { currentInstant }
        )

        coordinator.startSession()
        currentInstant = currentInstant.advanced(by: .seconds(45))

        // Primera finalización
        coordinator.endSession()
        #expect(coordinator.hasEnded)
        #expect(!coordinator.isSessionActive)

        // Intentos subsecuentes de finalización
        coordinator.endSession()
        coordinator.endSession()

        // Debe registrarse exactamente un evento de telemetría
        #expect(mockAnalytics.trackedEvents.count == 1)
        let event = mockAnalytics.trackedEvents[0]
        #expect(event.name == .readingSessionEnded)
        #expect(event.properties["duration_seconds"] as? Int == 45)
        #expect(event.properties["format"] as? String == "markdown")
    }

    @Test
    func testScenePhaseBackgroundSavesCheckpoint() async throws {
        let mockAnalytics = MockAnalyticsService()
        let mockRepo = MockReadingSessionRepository()
        let baseInstant = ContinuousClock.now
        var currentInstant = baseInstant
        let docID = UUID()

        let coordinator = ReadingSessionCoordinator(
            publicationID: docID,
            format: "pptx",
            analyticsService: mockAnalytics,
            readingSessionRepository: mockRepo,
            nowProvider: { currentInstant }
        )

        coordinator.startSession()
        currentInstant = currentInstant.advanced(by: .seconds(35))

        // Al pasar a background se genera checkpoint
        coordinator.handleScenePhaseChange(.background)

        // Esperar a que la Task asíncrona de guardado se complete
        try? await Task.sleep(for: .milliseconds(50))

        #expect(mockRepo.savedSessions.count == 1)
        #expect(mockRepo.savedSessions[0].publicationID == docID)
        #expect(mockRepo.savedSessions[0].activeSeconds == 35)
    }

    @Test
    func testReadingSessionEndedAllowlistRejectsForbiddenKeys() throws {
        let dirtyProps: [String: Any] = [
            "duration_seconds": 180,
            "format": "pdf",
            "title": "Documento Confidencial",
            "author": "Favio Cuentas",
            "text": "Texto del libro",
            "pages_read_count": 12,
            "document_id": UUID().uuidString,
            "publication_id": UUID().uuidString,
            "doc_id": "abc-123",
            "notes": "mi nota secreta",
            "email": "user@lectoria.app",
            "url": "https://lectoria.app/secret"
        ]

        let sanitized = PropertySanitizer.sanitize(dirtyProps, for: .readingSessionEnded)

        // Solo deben sobrevivir las claves de la allowlist cerrada
        #expect(sanitized.count == 2)
        #expect(sanitized["duration_seconds"] == "180")
        #expect(sanitized["format"] == "pdf")

        // Todas las demás deben ser descartadas
        #expect(sanitized["title"] == nil)
        #expect(sanitized["author"] == nil)
        #expect(sanitized["text"] == nil)
        #expect(sanitized["pages_read_count"] == nil)
        #expect(sanitized["document_id"] == nil)
        #expect(sanitized["publication_id"] == nil)
        #expect(sanitized["doc_id"] == nil)
        #expect(sanitized["notes"] == nil)
        #expect(sanitized["email"] == nil)
        #expect(sanitized["url"] == nil)
    }

    @Test
    func testAllowedFormatsValidation() throws {
        let validFormats = ["pdf", "epub", "txt", "markdown", "pptx", "pasted_text"]

        for fmt in validFormats {
            let props: [String: Any] = [
                "duration_seconds": 10,
                "format": fmt
            ]
            let sanitized = PropertySanitizer.sanitize(props, for: .readingSessionEnded)
            #expect(sanitized["format"] == fmt)
        }

        // Formato no autorizado
        let invalidProps: [String: Any] = [
            "duration_seconds": 10,
            "format": "docx"
        ]
        let sanitizedInvalid = PropertySanitizer.sanitize(invalidProps, for: .readingSessionEnded)
        #expect(sanitizedInvalid["format"] == nil)
    }

    @Test
    func testCheckpointsAndEndShareOneSessionID() async throws {
        let mockRepo = MockReadingSessionRepository()
        var currentInstant = ContinuousClock.now
        let coordinator = ReadingSessionCoordinator(
            publicationID: UUID(),
            format: "pdf",
            analyticsService: MockAnalyticsService(),
            readingSessionRepository: mockRepo,
            nowProvider: { currentInstant }
        )

        coordinator.startSession()
        currentInstant = currentInstant.advanced(by: .seconds(20))
        coordinator.handleScenePhaseChange(.background)
        coordinator.handleScenePhaseChange(.active)
        currentInstant = currentInstant.advanced(by: .seconds(20))
        coordinator.handleScenePhaseChange(.background)
        coordinator.endSession()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(Set(mockRepo.savedSessions.map(\.id)).count == 1)
        #expect(mockRepo.savedSessions.first?.id == coordinator.sessionID)
        #expect(mockRepo.savedSessions.first?.activeSeconds == 40)
    }

    @Test
    func testProgressProviderRecordsStartAndEndPercentage() async throws {
        let mockRepo = MockReadingSessionRepository()
        var progress = 0.2
        let coordinator = ReadingSessionCoordinator(
            publicationID: UUID(),
            format: "epub",
            analyticsService: MockAnalyticsService(),
            readingSessionRepository: mockRepo,
            progressProvider: { progress }
        )

        coordinator.startSession()
        progress = 0.5
        coordinator.endSession()
        try? await Task.sleep(for: .milliseconds(100))

        let saved = try #require(mockRepo.savedSessions.first)
        #expect(saved.startPercentage == 0.2)
        #expect(saved.endPercentage == 0.5)
    }

    @Test
    func testNilProgressProviderKeepsZero() async throws {
        let mockRepo = MockReadingSessionRepository()
        let coordinator = ReadingSessionCoordinator(
            publicationID: UUID(),
            format: "txt",
            analyticsService: MockAnalyticsService(),
            readingSessionRepository: mockRepo
        )

        coordinator.startSession()
        coordinator.endSession()
        try? await Task.sleep(for: .milliseconds(100))

        let saved = try #require(mockRepo.savedSessions.first)
        #expect(saved.startPercentage == 0)
        #expect(saved.endPercentage == 0)
    }

    /// El proveedor captura el estado de la vista (que a su vez retiene al coordinador):
    /// al terminar la sesión debe soltarse para no filtrar el lector entero.
    @Test
    func testEndSessionReleasesProgressProvider() async throws {
        final class Box { var value = 0.5 }
        var box: Box? = Box()
        weak var weakBox = box
        let coordinator = ReadingSessionCoordinator(
            publicationID: UUID(),
            format: "pdf",
            analyticsService: MockAnalyticsService(),
            readingSessionRepository: MockReadingSessionRepository(),
            progressProvider: { [box] in box?.value }
        )
        box = nil
        coordinator.startSession()
        #expect(weakBox != nil)
        coordinator.endSession()
        #expect(weakBox == nil)
        withExtendedLifetime(coordinator) {}
    }
}
