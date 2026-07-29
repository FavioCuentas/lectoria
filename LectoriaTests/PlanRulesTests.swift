import Testing
import Foundation
import SwiftData
@testable import Lectoria

// MARK: - PlanRulesTests

@MainActor
struct PlanRulesTests {
    private let container: ModelContainer
    private let mockSub: MockSubscriptionService
    private let dependencies: AppDependencies

    init() {
        self.container = ModelContainerFactory.create(isStoredInMemoryOnly: true)
        self.mockSub = MockSubscriptionService()
        self.dependencies = AppDependencies(
            modelContainer: container,
            authService: MockAuthService(),
            subscriptionService: mockSub
        )
    }

    @Test("Format gating enforcement for Free vs Premium")
    func testFormatGatingRules() async throws {
        let entitlementService = dependencies.entitlementService

        // Free Plan: EPUB, TXT, PastedText allowed
        mockSub.hasActiveSubscription = false
        let epubAccess = await entitlementService.canAccess(.importDocument(format: .epub))
        let txtAccess = await entitlementService.canAccess(.importDocument(format: .txt))
        let pastedAccess = await entitlementService.canAccess(.importDocument(format: .pastedText))

        #expect(epubAccess == .allowed)
        #expect(txtAccess == .allowed)
        #expect(pastedAccess == .allowed)

        // Free Plan: PDF, PPTX, Markdown blocked
        let pdfAccess = await entitlementService.canAccess(.importDocument(format: .pdf))
        let pptxAccess = await entitlementService.canAccess(.importDocument(format: .pptx))
        let mdAccess = await entitlementService.canAccess(.importDocument(format: .markdown))

        #expect(pdfAccess == .requiresPremium)
        #expect(pptxAccess == .requiresPremium)
        #expect(mdAccess == .requiresPremium)

        // Premium Plan: All formats allowed
        mockSub.hasActiveSubscription = true
        let pdfPremiumAccess = await entitlementService.canAccess(.importDocument(format: .pdf))
        let pptxPremiumAccess = await entitlementService.canAccess(.importDocument(format: .pptx))
        let mdPremiumAccess = await entitlementService.canAccess(.importDocument(format: .markdown))

        #expect(pdfPremiumAccess == .allowed)
        #expect(pptxPremiumAccess == .allowed)
        #expect(mdPremiumAccess == .allowed)
    }

    @Test("Rule of 5 active documents on Free plan")
    func testRuleOfFiveActiveDocuments() async throws {
        let entitlementService = dependencies.entitlementService
        let pubRepo = dependencies.publicationRepository

        mockSub.hasActiveSubscription = false

        // Save 5 active EPUB documents
        for i in 1...5 {
            let pub = PublicationRecord(
                id: UUID(),
                title: "Doc \(i)",
                publicationType: .epub,
                localFileName: "doc_\(i).epub",
                mimeType: "application/epub+zip",
                fileSize: 100,
                sha256: "sha_\(i)",
                isArchived: false
            )
            try await pubRepo.save(pub)
        }

        // Attempting to import 6th active document on Free is blocked
        let importCheck = await entitlementService.canAccess(.importDocument(format: .epub))
        #expect(importCheck == .limitReached(message: "Has alcanzado el límite de 5 documentos activos en el plan Free."))
    }

    @Test("Downgrade preserves all user documents and flags excess as archived")
    func testDowngradeDataPreservation() async throws {
        let pubRepo = dependencies.publicationRepository

        // Premium user imports 7 documents
        mockSub.hasActiveSubscription = true

        var createdRecords: [PublicationRecord] = []
        for i in 1...7 {
            let pub = PublicationRecord(
                id: UUID(),
                title: "Documento Premium \(i)",
                publicationType: .epub,
                localFileName: "premium_\(i).epub",
                mimeType: "application/epub+zip",
                fileSize: 200,
                sha256: "sha_premium_\(i)",
                isArchived: false
            )
            try await pubRepo.save(pub)
            createdRecords.append(pub)
        }

        let allPubsBeforeDowngrade = try await pubRepo.fetchAll()
        #expect(allPubsBeforeDowngrade.count == 7)

        // Downgrade to Free
        mockSub.hasActiveSubscription = false

        // Simulate auto-archiving excess documents (docs 6 and 7 become archived)
        var updatedRecords = allPubsBeforeDowngrade
        for index in updatedRecords.indices {
            if index >= 5 {
                updatedRecords[index].isArchived = true
                try await pubRepo.save(updatedRecords[index])
            }
        }

        let allPubsAfterDowngrade = try await pubRepo.fetchAll()
        // Total document count remains 7 (0 data loss)
        #expect(allPubsAfterDowngrade.count == 7)

        let activeCount = allPubsAfterDowngrade.filter { !$0.isArchived }.count
        let archivedCount = allPubsAfterDowngrade.filter { $0.isArchived }.count

        #expect(activeCount == 5)
        #expect(archivedCount == 2)
    }

    @Test("Lifetime tier rules evaluation")
    func testLifetimeTierCapabilities() async throws {
        let lifetimeEnt = SubscriptionEntitlement(
            productID: StoreKitSubscriptionService.lifetimeProductID,
            status: "active"
        )
        mockSub.hasActiveSubscription = true
        mockSub.activeEntitlement = lifetimeEnt

        let entitlementService = dependencies.entitlementService
        let currentEnts = await entitlementService.currentEntitlements()

        #expect(currentEnts.tier == .lifetime)
        #expect(currentEnts.maxActiveDocuments == nil)
        #expect(currentEnts.canUseLocalTranslation == true)
        #expect(currentEnts.maximumDevices == 3)
        #expect(currentEnts.allowedFormats.count == PublicationType.allCases.count)
    }
}
