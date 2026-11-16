import Foundation

// MARK: - Entitlements

/// Fuente única de verdad sobre los derechos y capacidades activas del usuario.
public struct Entitlements: Equatable, Sendable {
    public let tier: SubscriptionTier
    public let maxActiveDocuments: Int?
    public let allowedFormats: Set<PublicationType>
    public let canUseAdvancedAnnotations: Bool
    public let canUseAdvancedExport: Bool
    public let canUseAdvancedStatistics: Bool
    public let canUseLocalAI: Bool
    public let monthlyAILimit: Int?
    public let canUseLocalTranslation: Bool
    public let maximumDevices: Int
    public let canUseInstitutionalLibrary: Bool
    public let canManageDevices: Bool
    public let isActive: Bool
    public let expirationDate: Date?

    public init(
        tier: SubscriptionTier,
        maxActiveDocuments: Int?,
        allowedFormats: Set<PublicationType>,
        canUseAdvancedAnnotations: Bool,
        canUseAdvancedExport: Bool,
        canUseAdvancedStatistics: Bool,
        canUseLocalAI: Bool,
        monthlyAILimit: Int?,
        canUseLocalTranslation: Bool,
        maximumDevices: Int,
        canUseInstitutionalLibrary: Bool,
        canManageDevices: Bool,
        isActive: Bool,
        expirationDate: Date?
    ) {
        self.tier = tier
        self.maxActiveDocuments = maxActiveDocuments
        self.allowedFormats = allowedFormats
        self.canUseAdvancedAnnotations = canUseAdvancedAnnotations
        self.canUseAdvancedExport = canUseAdvancedExport
        self.canUseAdvancedStatistics = canUseAdvancedStatistics
        self.canUseLocalAI = canUseLocalAI
        self.monthlyAILimit = monthlyAILimit
        self.canUseLocalTranslation = canUseLocalTranslation
        self.maximumDevices = maximumDevices
        self.canUseInstitutionalLibrary = canUseInstitutionalLibrary
        self.canManageDevices = canManageDevices
        self.isActive = isActive
        self.expirationDate = expirationDate
    }

    /// Genera la configuración predeterminada de Entitlements para un nivel dado.
    public static func defaultForTier(_ tier: SubscriptionTier, expirationDate: Date? = nil) -> Entitlements {
        switch tier {
        case .free:
            return Entitlements(
                tier: .free,
                maxActiveDocuments: 5,
                // Plan Free: solo EPUB, TXT y texto pegado; PDF, PPTX y Markdown requieren Premium.
                allowedFormats: [.epub, .txt, .pastedText],
                canUseAdvancedAnnotations: true,
                canUseAdvancedExport: false,
                canUseAdvancedStatistics: false,
                canUseLocalAI: true,
                monthlyAILimit: 3,
                canUseLocalTranslation: false,
                maximumDevices: 1,
                canUseInstitutionalLibrary: false,
                canManageDevices: false,
                isActive: true,
                expirationDate: expirationDate
            )
        case .premiumFounder, .premiumRegular, .lifetime:
            return Entitlements(
                tier: tier,
                maxActiveDocuments: nil,
                allowedFormats: Set(PublicationType.allCases),
                canUseAdvancedAnnotations: true,
                canUseAdvancedExport: true,
                canUseAdvancedStatistics: true,
                canUseLocalAI: true,
                monthlyAILimit: nil,
                canUseLocalTranslation: true,
                maximumDevices: 3,
                canUseInstitutionalLibrary: false,
                canManageDevices: true,
                isActive: true,
                expirationDate: expirationDate
            )
        case .institutional:
            return Entitlements(
                tier: .institutional,
                maxActiveDocuments: nil,
                allowedFormats: Set(PublicationType.allCases),
                canUseAdvancedAnnotations: true,
                canUseAdvancedExport: true,
                canUseAdvancedStatistics: true,
                canUseLocalAI: true,
                monthlyAILimit: nil,
                canUseLocalTranslation: true,
                maximumDevices: 3,
                canUseInstitutionalLibrary: true,
                canManageDevices: true,
                isActive: true,
                expirationDate: expirationDate
            )
        }
    }
}
