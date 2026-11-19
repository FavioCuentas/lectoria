import Testing
import Foundation
@testable import Lectoria

// MARK: - Pantalla activa al leer

@MainActor
struct ScreenAwakeControllerTests {
    private func makeDefaults() -> UserDefaults {
        let name = "ScreenAwakeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func testDisabledByDefaultAndPersisted() {
        let defaults = makeDefaults()
        let controller = ScreenAwakeController(defaults: defaults) { _ in }
        #expect(controller.isEnabled == false)
        controller.isEnabled = true
        #expect(ScreenAwakeController(defaults: defaults) { _ in }.isEnabled == true)
    }

    @Test func testKeepsScreenOnOnlyWhileAReaderIsOpenAndEnabled() {
        var idleTimerDisabled = false
        let controller = ScreenAwakeController(defaults: makeDefaults()) { idleTimerDisabled = $0 }

        controller.readerDidAppear()
        #expect(idleTimerDisabled == false) // ajuste apagado

        controller.isEnabled = true
        #expect(idleTimerDisabled == true)

        controller.readerDidDisappear()
        #expect(idleTimerDisabled == false)
    }

    /// Un lector dentro de otro (presentación que abre su PDF) no debe apagar el ajuste antes de tiempo.
    @Test func testNestedReadersKeepScreenOnUntilTheLastCloses() {
        var idleTimerDisabled = false
        let controller = ScreenAwakeController(defaults: makeDefaults()) { idleTimerDisabled = $0 }
        controller.isEnabled = true

        controller.readerDidAppear()
        controller.readerDidAppear()
        controller.readerDidDisappear()
        #expect(idleTimerDisabled == true)
        controller.readerDidDisappear()
        #expect(idleTimerDisabled == false)
        controller.readerDidDisappear() // un cierre de más no deja el contador negativo
        controller.readerDidAppear()
        #expect(idleTimerDisabled == true)
    }

    @Test func testTurningSettingOffWhileReadingRestoresIdleTimer() {
        var idleTimerDisabled = false
        let controller = ScreenAwakeController(defaults: makeDefaults()) { idleTimerDisabled = $0 }
        controller.isEnabled = true
        controller.readerDidAppear()
        controller.isEnabled = false
        #expect(idleTimerDisabled == false)
    }
}

// MARK: - Respaldo automático

private final class SpySyncService: SyncService, @unchecked Sendable {
    var isSyncing = false
    var lastSyncedAt: Date?
    var syncCalls = 0
    var shouldFail = false

    func syncAll() async throws {
        syncCalls += 1
        if shouldFail { throw URLError(.notConnectedToInternet) }
        lastSyncedAt = Date()
    }

    func performInitialSync() async throws { try await syncAll() }
}

@MainActor
struct AutoBackupCoordinatorTests {
    @Test func testSkipsWhenSignedOut() async {
        let sync = SpySyncService()
        let backup = AutoBackupCoordinator(sync: sync, isSignedIn: { false })
        await backup.backupIfNeeded()
        #expect(sync.syncCalls == 0)
    }

    @Test func testBacksUpWhenNeverSynced() async {
        let sync = SpySyncService()
        let backup = AutoBackupCoordinator(sync: sync, isSignedIn: { true })
        await backup.backupIfNeeded()
        #expect(sync.syncCalls == 1)
        #expect(backup.lastAttemptFailed == false)
    }

    @Test func testSkipsWithinMinimumInterval() async {
        let now = Date()
        let sync = SpySyncService()
        sync.lastSyncedAt = now.addingTimeInterval(-60)
        let backup = AutoBackupCoordinator(sync: sync, isSignedIn: { true }, minimumInterval: 300, now: { now })
        await backup.backupIfNeeded()
        #expect(sync.syncCalls == 0)

        sync.lastSyncedAt = now.addingTimeInterval(-301)
        await backup.backupIfNeeded()
        #expect(sync.syncCalls == 1)
    }

    @Test func testFailureIsRecordedAndRetriedNextTime() async {
        let sync = SpySyncService()
        sync.shouldFail = true
        let backup = AutoBackupCoordinator(sync: sync, isSignedIn: { true })
        await backup.backupIfNeeded()
        #expect(backup.lastAttemptFailed == true)

        sync.shouldFail = false
        await backup.backupIfNeeded()
        #expect(sync.syncCalls == 2)
        #expect(backup.lastAttemptFailed == false)
    }

    @Test func testStatusText() {
        let now = Date()
        #expect(AutoBackupCoordinator.statusText(lastSyncedAt: nil, isRunning: false, failed: false, now: now) == "Nunca")
        #expect(AutoBackupCoordinator.statusText(lastSyncedAt: now, isRunning: true, failed: false, now: now) == "Guardando…")
        #expect(AutoBackupCoordinator.statusText(lastSyncedAt: now, isRunning: false, failed: true, now: now) == "Sin conexión")
        #expect(AutoBackupCoordinator.statusText(lastSyncedAt: now.addingTimeInterval(-20), isRunning: false, failed: false, now: now) == "Ahora")
        #expect(AutoBackupCoordinator.statusText(lastSyncedAt: now.addingTimeInterval(-600), isRunning: false, failed: false, now: now) != "Nunca")
    }
}
