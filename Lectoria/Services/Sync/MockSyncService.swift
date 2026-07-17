import Foundation
import Observation

// MARK: - MockSyncService

/// Implementación simulada de `SyncService` para pruebas y vistas previas.
@Observable
public final class MockSyncService: SyncService, @unchecked Sendable {
    public var isSyncing: Bool = false
    public var lastSyncedAt: Date? = nil
    
    public var shouldFail = false
    
    public init(lastSyncedAt: Date? = nil) {
        self.lastSyncedAt = lastSyncedAt
    }
    
    public func syncAll() async throws {
        if shouldFail {
            throw NSError(domain: "MockSync", code: 500, userInfo: [NSLocalizedDescriptionKey: "Error simulado de red en sincronización."])
        }
        isSyncing = true
        try? await Task.sleep(for: .milliseconds(300))
        lastSyncedAt = Date()
        isSyncing = false
    }
    
    public func performInitialSync() async throws {
        try await syncAll()
    }
}
