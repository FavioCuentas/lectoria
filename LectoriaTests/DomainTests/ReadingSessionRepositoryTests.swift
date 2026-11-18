import Testing
import Foundation
import SwiftData
@testable import Lectoria

@MainActor
struct ReadingSessionRepositoryTests {

    @Test
    func testSaveSameIDTwiceUpdatesInsteadOfDuplicating() async throws {
        let container = ModelContainerFactory.create(isStoredInMemoryOnly: true)
        let repository = SwiftDataReadingSessionRepository(container: container)
        let sessionID = UUID()
        let publicationID = UUID()
        let start = Date()

        try await repository.save(ReadingSession(
            id: sessionID, publicationID: publicationID,
            startedAt: start, endedAt: start.addingTimeInterval(30),
            activeSeconds: 30, startPercentage: 0.1, endPercentage: 0.1
        ))
        try await repository.save(ReadingSession(
            id: sessionID, publicationID: publicationID,
            startedAt: start, endedAt: start.addingTimeInterval(90),
            activeSeconds: 90, startPercentage: 0.1, endPercentage: 0.4
        ))

        let all = try await repository.fetchAll()
        #expect(all.count == 1)
        #expect(all.first?.activeSeconds == 90)
        #expect(all.first?.endPercentage == 0.4)
    }
}
