import Foundation
import Observation
import os

private let logger = Logger(subsystem: "com.orvexa.Lectoria", category: "Backup")

// MARK: - AutoBackupCoordinator

/// Copia de seguridad automática y silenciosa de marcadores, destacados, notas y progreso.
///
/// Se pide al abrir la app y cada vez que vuelve a primer plano; solo corre con la sesión
/// iniciada y como mucho una vez cada `minimumInterval`. Un fallo no interrumpe al usuario:
/// queda como estado en Perfil y se reintenta la próxima vez.
@MainActor
@Observable
final class AutoBackupCoordinator {
    @ObservationIgnored private let sync: any SyncService
    @ObservationIgnored private let isSignedIn: () -> Bool
    @ObservationIgnored private let minimumInterval: TimeInterval
    @ObservationIgnored private let now: () -> Date

    private(set) var isRunning = false
    private(set) var lastAttemptFailed = false
    private(set) var lastSyncedAt: Date?

    init(
        sync: any SyncService,
        isSignedIn: @escaping () -> Bool,
        minimumInterval: TimeInterval = 5 * 60,
        now: @escaping () -> Date = Date.init
    ) {
        self.sync = sync
        self.isSignedIn = isSignedIn
        self.minimumInterval = minimumInterval
        self.now = now
        self.lastSyncedAt = sync.lastSyncedAt
    }

    func backupIfNeeded() async {
        guard isSignedIn(), !isRunning, !sync.isSyncing else { return }
        if let last = sync.lastSyncedAt, !lastAttemptFailed,
           now().timeIntervalSince(last) < minimumInterval {
            lastSyncedAt = last
            return
        }
        isRunning = true
        defer { isRunning = false }
        do {
            try await sync.syncAll()
            lastAttemptFailed = false
        } catch {
            logger.error("Copia de seguridad fallida: \(String(describing: error))")
            lastAttemptFailed = true
        }
        lastSyncedAt = sync.lastSyncedAt
    }

    /// Texto corto para la fila de Perfil.
    static func statusText(lastSyncedAt: Date?, isRunning: Bool, failed: Bool, now: Date = Date()) -> String {
        if isRunning { return String(localized: "Guardando…", comment: "Backup status: running") }
        if failed { return String(localized: "Sin conexión", comment: "Backup status: last attempt failed") }
        guard let lastSyncedAt else { return String(localized: "Nunca", comment: "Backup status: never") }
        if now.timeIntervalSince(lastSyncedAt) < 60 { return String(localized: "Ahora", comment: "Backup status: just now") }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: lastSyncedAt, relativeTo: now)
    }
}
