import Foundation
import SwiftUI

// MARK: - ReadingSessionCoordinator

/// Coordinador de ciclo de vida para sesiones de lectura en Lectoria.
///
/// Gestiona la medición del tiempo activo de lectura con reloj monotónico (`ContinuousClock`),
/// asegurando que:
/// 1. Solo comienza a medir cuando el documento abre con éxito.
/// 2. Se pausa cuando la app pasa a segundo plano o se vuelve inactiva.
/// 3. Se reanuda exclusivamente al volver a primer plano activo.
/// 4. Guarda un checkpoint al suspenderse.
/// 5. Finaliza e informa `reading_session_ended` de forma estrictamente idempotente (máximo una vez).
@MainActor
public final class ReadingSessionCoordinator {
    public let publicationID: UUID
    public let format: String

    private let analyticsService: any AnalyticsService
    private let readingSessionRepository: (any ReadingSessionRepository)?
    private let nowProvider: () -> ContinuousClock.Instant

    // Estado interno
    private var startedAt: Date?
    private var lastResumeInstant: ContinuousClock.Instant?
    private var accumulatedDuration: Duration = .zero
    public private(set) var isSessionActive: Bool = false
    public private(set) var hasEnded: Bool = false

    /// Duración activa acumulada actual en segundos (útil para pruebas e inspección).
    public var currentActiveSeconds: Int {
        var total = accumulatedDuration
        if let last = lastResumeInstant {
            total += nowProvider() - last
        }
        return max(0, Int(total.components.seconds))
    }

    public init(
        publicationID: UUID,
        format: String,
        analyticsService: any AnalyticsService,
        readingSessionRepository: (any ReadingSessionRepository)? = nil,
        nowProvider: @escaping () -> ContinuousClock.Instant = { ContinuousClock.now }
    ) {
        self.publicationID = publicationID
        self.format = format
        self.analyticsService = analyticsService
        self.readingSessionRepository = readingSessionRepository
        self.nowProvider = nowProvider
    }

    /// Inicia la sesión de lectura. Debe invocarse únicamente cuando el lector haya completado
    /// la carga y renderizado inicial del documento con éxito.
    public func startSession() {
        guard !isSessionActive && !hasEnded else { return }

        self.startedAt = Date()
        self.lastResumeInstant = nowProvider()
        self.isSessionActive = true
    }

    /// Reacciona a los cambios en el ciclo de vida de la escena de SwiftUI.
    public func handleScenePhaseChange(_ phase: ScenePhase) {
        guard isSessionActive && !hasEnded else { return }

        switch phase {
        case .inactive, .background:
            // Pausar medición de tiempo activo
            if let last = lastResumeInstant {
                accumulatedDuration += nowProvider() - last
                lastResumeInstant = nil
            }
            // Guardar checkpoint local de seguridad
            saveCheckpoint()

        case .active:
            // Reanudar medición de tiempo activo si estaba pausada
            if lastResumeInstant == nil {
                lastResumeInstant = nowProvider()
            }

        @unknown default:
            break
        }
    }

    /// Finaliza la sesión de lectura de forma idempotente y despacha el evento `reading_session_ended`.
    public func endSession() {
        guard isSessionActive && !hasEnded else { return }
        hasEnded = true

        if let last = lastResumeInstant {
            accumulatedDuration += nowProvider() - last
            lastResumeInstant = nil
        }
        isSessionActive = false

        let totalSeconds = max(0, Int(accumulatedDuration.components.seconds))
        let startTime = startedAt ?? Date()
        let endTime = Date()

        // 1. Guardar registro histórico local en repositorio SwiftData
        if let repo = readingSessionRepository {
            let sessionRecord = ReadingSession(
                publicationID: publicationID,
                startedAt: startTime,
                endedAt: endTime,
                activeSeconds: totalSeconds,
                startPercentage: 0.0,
                endPercentage: 0.0
            )
            Task {
                try? await repo.save(sessionRecord)
            }
        }

        // 2. Despachar evento a telemetría (Zero PII: solo duration_seconds y format)
        analyticsService.track(.readingSessionEnded, properties: [
            "duration_seconds": totalSeconds,
            "format": format
        ])
    }

    private func saveCheckpoint() {
        guard let repo = readingSessionRepository, let startTime = startedAt else { return }
        let currentSeconds = max(0, Int(accumulatedDuration.components.seconds))
        let checkpoint = ReadingSession(
            publicationID: publicationID,
            startedAt: startTime,
            endedAt: Date(),
            activeSeconds: currentSeconds,
            startPercentage: 0.0,
            endPercentage: 0.0
        )
        Task {
            try? await repo.save(checkpoint)
        }
    }
}
