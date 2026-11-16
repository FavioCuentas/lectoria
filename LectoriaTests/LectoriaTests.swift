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
        
        #expect(free.displayName == "Lectoría Free")
        #expect(annual.displayName == "Premium Regular")
        #expect(lifetime.displayName == "Lectoría Lifetime")
        #expect(inst.displayName == "Lectoría Institucional")
    }
    
    @Test func testEntitlementManagerFreePlanLimits() async throws {
        let mockPubRepo = await MockPublicationRepository()
        let mockHlRepo = await MockHighlightRepository()
        let mockNoteRepo = await MockNoteRepository()
        let mockAIRepo = await MockAIUsageRepository()
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
        let mockPubRepo = await MockPublicationRepository()
        let mockHlRepo = await MockHighlightRepository()
        let mockNoteRepo = await MockNoteRepository()
        let mockAIRepo = await MockAIUsageRepository()
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

    @Test func testMockAuthServiceLifecycle() async throws {
        let authService = MockAuthService()
        #expect(authService.currentUser == nil)

        // Apple Auth with Nonce
        try await authService.signInWithApple(identityToken: "test_token", rawNonce: "nonce_123", email: "apple@lectoria.app", fullName: "Apple User")
        #expect(authService.currentUser != nil)
        #expect(authService.currentUser?.email == "apple@lectoria.app")

        try await authService.signOut()
        #expect(authService.currentUser == nil)

        // Google Auth
        try await authService.signInWithGoogle(idToken: "google_token", accessToken: "google_access")
        #expect(authService.currentUser != nil)
        #expect(authService.currentUser?.email == "google_user@lectoria.app")

        try await authService.signOut()
        #expect(authService.currentUser == nil)

        // OTP Email Auth
        try await authService.sendOTPCode(to: "user@lectoria.app")
        try await authService.verifyOTPCode(email: "user@lectoria.app", code: "123456")
        #expect(authService.currentUser != nil)
        #expect(authService.currentUser?.email == "user@lectoria.app")
    }
}

// MARK: - Mock Repositories for Tests

@MainActor
private final class MockPublicationRepository: PublicationRepository, @unchecked Sendable {
    var pubs: [PublicationRecord] = []
    func fetchAll() async throws -> [PublicationRecord] { pubs }
    func fetch(id: UUID) async throws -> PublicationRecord? { pubs.first { $0.id == id } }
    func save(_ publication: PublicationRecord) async throws {
        if let idx = pubs.firstIndex(where: { $0.id == publication.id }) {
            pubs[idx] = publication
        } else {
            pubs.append(publication)
        }
    }
    func delete(id: UUID) async throws { pubs.removeAll { $0.id == id } }
}

@MainActor
private final class MockHighlightRepository: HighlightRepository, @unchecked Sendable {
    var highlights: [Highlight] = []
    func fetchAll() async throws -> [Highlight] { highlights }
    func fetch(forPublication publicationID: UUID) async throws -> [Highlight] { highlights.filter { $0.publicationID == publicationID } }
    func fetch(id: UUID) async throws -> Highlight? { highlights.first { $0.id == id } }
    func save(_ highlight: Highlight) async throws { highlights.append(highlight) }
    func delete(id: UUID) async throws { highlights.removeAll { $0.id == id } }
}

@MainActor
private final class MockNoteRepository: NoteRepository, @unchecked Sendable {
    var notes: [Note] = []
    func fetchAll() async throws -> [Note] { notes }
    func fetch(forPublication publicationID: UUID) async throws -> [Note] { notes.filter { $0.publicationID == publicationID } }
    func fetch(id: UUID) async throws -> Note? { notes.first { $0.id == id } }
    func save(_ note: Note) async throws { notes.append(note) }
    func delete(id: UUID) async throws { notes.removeAll { $0.id == id } }
}

@MainActor
private final class MockAIUsageRepository: AIUsageRepository, @unchecked Sendable {
    var usages: [AIUsage] = []
    func fetchAll() async throws -> [AIUsage] { usages }
    func save(_ usage: AIUsage) async throws { usages.append(usage) }
    func fetchTotalCreditsUsedToday() async throws -> Int { usages.count }
}
