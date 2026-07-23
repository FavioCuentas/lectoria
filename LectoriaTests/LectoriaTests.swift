import Testing
import Foundation
@testable import Lectoria

struct LectoriaTests {

    @Test func testPlanTypeProperties() async throws {
        let free = PlanType.free
        let annual = PlanType.premiumAnnual
        let lifetime = PlanType.premiumLifetime
        let inst = PlanType.institutional
        
        #expect(free.isUnlimited == false)
        #expect(annual.isUnlimited == true)
        #expect(lifetime.isUnlimited == true)
        #expect(inst.isUnlimited == true)
        
        #expect(free.displayName == "Plan Gratuito")
        #expect(annual.displayName == "Premium Anual")
        #expect(lifetime.displayName == "Premium De por Vida")
        #expect(inst.displayName == "Acceso Institucional")
    }
    
    @Test func testEntitlementManagerFreePlanLimits() async throws {
        let mockPubRepo = MockPublicationRepository()
        let mockHlRepo = MockHighlightRepository()
        let mockNoteRepo = MockNoteRepository()
        let mockAIRepo = MockAIUsageRepository()
        let mockSub = MockSubscriptionService(hasActiveSubscription: false)
        
        let entitlementManager = EntitlementManager(
            publicationRepository: mockPubRepo,
            highlightRepository: mockHlRepo,
            noteRepository: mockNoteRepo,
            aiUsageRepository: mockAIRepo,
            subscriptionService: mockSub
        )
        
        let plan = await entitlementManager.currentPlan()
        #expect(plan == .free)
        
        let canImport = await entitlementManager.canPerformAction(.importDocument)
        #expect(canImport == true)
        
        let limits = await entitlementManager.getLimits()
        #expect(limits.activePlan == .free)
        #expect(limits.hasPremiumAccess == false)
    }

    @Test func testEntitlementManagerLifetimePlanLimits() async throws {
        let mockPubRepo = MockPublicationRepository()
        let mockHlRepo = MockHighlightRepository()
        let mockNoteRepo = MockNoteRepository()
        let mockAIRepo = MockAIUsageRepository()
        let lifetimeEnt = SubscriptionEntitlement(
            productID: "com.lectoria.premium.lifetime",
            status: "active"
        )
        let mockSub = MockSubscriptionService(hasActiveSubscription: true, activeEntitlement: lifetimeEnt)
        
        let entitlementManager = EntitlementManager(
            publicationRepository: mockPubRepo,
            highlightRepository: mockHlRepo,
            noteRepository: mockNoteRepo,
            aiUsageRepository: mockAIRepo,
            subscriptionService: mockSub
        )
        
        let plan = await entitlementManager.currentPlan()
        #expect(plan == .premiumLifetime)
        
        let limits = await entitlementManager.getLimits()
        #expect(limits.activePlan == .premiumLifetime)
        #expect(limits.hasPremiumAccess == true)
    }
}

// MARK: - Mock Repositories for Tests

private final class MockPublicationRepository: PublicationRepository, @unchecked Sendable {
    var pubs: [PublicationRecord] = []
    func fetchAll() async throws -> [PublicationRecord] { pubs }
    func fetch(byID id: UUID) async throws -> PublicationRecord? { pubs.first { $0.id == id } }
    func save(_ publication: PublicationRecord) async throws {
        if let idx = pubs.firstIndex(where: { $0.id == publication.id }) {
            pubs[idx] = publication
        } else {
            pubs.append(publication)
        }
    }
    func delete(byID id: UUID) async throws { pubs.removeAll { $0.id == id } }
}

private final class MockHighlightRepository: HighlightRepository, @unchecked Sendable {
    var highlights: [HighlightRecord] = []
    func fetchAll() async throws -> [HighlightRecord] { highlights }
    func fetch(forPublicationID pubID: UUID) async throws -> [HighlightRecord] { highlights.filter { $0.publicationID == pubID } }
    func save(_ highlight: HighlightRecord) async throws { highlights.append(highlight) }
    func delete(byID id: UUID) async throws { highlights.removeAll { $0.id == id } }
}

private final class MockNoteRepository: NoteRepository, @unchecked Sendable {
    var notes: [NoteRecord] = []
    func fetchAll() async throws -> [NoteRecord] { notes }
    func fetch(forPublicationID pubID: UUID) async throws -> [NoteRecord] { notes.filter { $0.publicationID == pubID } }
    func save(_ note: NoteRecord) async throws { notes.append(note) }
    func delete(byID id: UUID) async throws { notes.removeAll { $0.id == id } }
}

private final class MockAIUsageRepository: AIUsageRepository, @unchecked Sendable {
    var usages: [AIUsage] = []
    func fetchAll() async throws -> [AIUsage] { usages }
    func fetchCurrentMonthUsages() async throws -> [AIUsage] { usages }
    func save(_ usage: AIUsage) async throws { usages.append(usage) }
}
