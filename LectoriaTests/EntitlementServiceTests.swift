import Testing
import Foundation
@testable import Lectoria

// MARK: - EntitlementServiceTests

struct EntitlementServiceTests {

    @Test("SubscriptionTier properties and display names")
    func testSubscriptionTierProperties() async throws {
        #expect(SubscriptionTier.free.isUnlimited == false)
        #expect(SubscriptionTier.premiumFounder.isUnlimited == true)
        #expect(SubscriptionTier.premiumRegular.isUnlimited == true)
        #expect(SubscriptionTier.lifetime.isUnlimited == true)
        #expect(SubscriptionTier.institutional.isUnlimited == true)

        #expect(SubscriptionTier.free.displayName == "Lectoría Free")
        #expect(SubscriptionTier.premiumFounder.displayName == "Premium Fundador")
        #expect(SubscriptionTier.premiumRegular.displayName == "Premium Regular")
        #expect(SubscriptionTier.lifetime.displayName == "Lectoría Lifetime")
        #expect(SubscriptionTier.institutional.displayName == "Lectoría Institucional")
    }

    @Test("Entitlements defaults per tier")
    func testEntitlementsDefaults() async throws {
        let freeEnt = Entitlements.defaultForTier(.free)
        #expect(freeEnt.tier == .free)
        #expect(freeEnt.maxActiveDocuments == 5)
        #expect(freeEnt.allowedFormats == [.epub, .txt, .pastedText])
        #expect(freeEnt.canUseLocalTranslation == false)
        #expect(freeEnt.monthlyAILimit == 10)
        #expect(freeEnt.maximumDevices == 1)

        let founderEnt = Entitlements.defaultForTier(.premiumFounder)
        #expect(founderEnt.tier == .premiumFounder)
        #expect(founderEnt.maxActiveDocuments == nil)
        #expect(founderEnt.allowedFormats.count == PublicationType.allCases.count)
        #expect(founderEnt.canUseLocalTranslation == true)
        #expect(founderEnt.monthlyAILimit == nil)
        #expect(founderEnt.maximumDevices == 3)

        let lifetimeEnt = Entitlements.defaultForTier(.lifetime)
        #expect(lifetimeEnt.tier == .lifetime)
        #expect(lifetimeEnt.maxActiveDocuments == nil)
        #expect(lifetimeEnt.canUseLocalTranslation == true)
        #expect(lifetimeEnt.maximumDevices == 3)

        let instEnt = Entitlements.defaultForTier(.institutional)
        #expect(instEnt.tier == .institutional)
        #expect(instEnt.canUseInstitutionalLibrary == true)
    }

    @Test("EntitlementSource priority resolution")
    func testEntitlementSourcePriority() async throws {
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

        let sources: [EntitlementSource] = [
            .free,
            .institutionalGracePeriod(expirationDate: Date()),
            .appleSubscription(tier: .premiumRegular),
            .lifetime,
            .institutional(licenseID: UUID())
        ]

        let highest = entitlementManager.resolveHighestPrioritySource(sources)
        #expect(highest == .lifetime)
        #expect(highest.priority == 1)
        #expect(highest.equivalentTier == .lifetime)

        let secondarySources: [EntitlementSource] = [
            .free,
            .institutionalGracePeriod(expirationDate: Date()),
            .appleSubscription(tier: .premiumFounder)
        ]

        let highestSecondary = entitlementManager.resolveHighestPrioritySource(secondarySources)
        #expect(highestSecondary == .appleSubscription(tier: .premiumFounder))
        #expect(highestSecondary.priority == 2)
        #expect(highestSecondary.equivalentTier == .premiumFounder)
    }

    @Test("FeatureAccessResult evaluation for Free plan")
    func testFeatureAccessResultFreePlan() async throws {
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

        // EPUB is allowed on Free
        let epubAccess = await entitlementManager.canAccess(.importDocument(format: .epub))
        #expect(epubAccess == .allowed)

        // PDF requires Premium on Free
        let pdfAccess = await entitlementManager.canAccess(.importDocument(format: .pdf))
        #expect(pdfAccess == .requiresPremium)

        // PPTX requires Premium on Free
        let pptxAccess = await entitlementManager.canAccess(.importDocument(format: .pptx))
        #expect(pptxAccess == .requiresPremium)

        // Markdown requires Premium on Free
        let mdAccess = await entitlementManager.canAccess(.importDocument(format: .markdown))
        #expect(mdAccess == .requiresPremium)

        // Translation requires Premium on Free
        let translationAccess = await entitlementManager.canAccess(.useLocalTranslation)
        #expect(translationAccess == .requiresPremium)

        // Institutional library requires Institutional account
        let instAccess = await entitlementManager.canAccess(.accessInstitutionalLibrary)
        #expect(instAccess == .institutionalOnly)
    }

    @Test("FeatureAccessResult evaluation for Premium plan")
    func testFeatureAccessResultPremiumPlan() async throws {
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

        // PDF is allowed on Premium
        let pdfAccess = await entitlementManager.canAccess(.importDocument(format: .pdf))
        #expect(pdfAccess == .allowed)

        // PPTX is allowed on Premium
        let pptxAccess = await entitlementManager.canAccess(.importDocument(format: .pptx))
        #expect(pptxAccess == .allowed)

        // Translation is allowed on Premium
        let translationAccess = await entitlementManager.canAccess(.useLocalTranslation)
        #expect(translationAccess == .allowed)

        // Devices management allowed on Premium
        let deviceAccess = await entitlementManager.canAccess(.manageDevices)
        #expect(deviceAccess == .allowed)
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
