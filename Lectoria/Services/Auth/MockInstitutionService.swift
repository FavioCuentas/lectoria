import Foundation

// MARK: - MockInstitutionService

/// Mock configurable para pruebas unitarias y previews de SwiftUI.
public final class MockInstitutionService: InstitutionService, @unchecked Sendable {
    public struct MockCode: Sendable {
        public let code: String
        public let institution: InstitutionInfo
        public let isActive: Bool
        public let expiresAt: Date?
        public var maxUses: Int
        public var currentUses: Int

        public init(
            code: String,
            institution: InstitutionInfo,
            isActive: Bool = true,
            expiresAt: Date? = nil,
            maxUses: Int = 100,
            currentUses: Int = 0
        ) {
            self.code = code
            self.institution = institution
            self.isActive = isActive
            self.expiresAt = expiresAt
            self.maxUses = maxUses
            self.currentUses = currentUses
        }
    }

    public struct MockTicket: Sendable {
        public let id: String
        public let institutionID: UUID
        public let code: MockCode?
        public var status: String // pending, active, used, revoked, expired
        public let email: String
    }

    private var mockDomains: [String: InstitutionInfo]
    private var mockCodes: [String: MockCode]
    public var shouldFailNetwork: Bool
    public var shouldFailOTPSend: Bool = false
    public var claimedMemberships: [(email: String, ticketOrDomain: String)] = []
    public var mockTickets: [String: MockTicket] = [:]

    public init(
        mockDomains: [String: InstitutionInfo] = [:],
        mockCodes: [String: MockCode] = [:],
        shouldFailNetwork: Bool = false
    ) {
        self.mockDomains = mockDomains
        self.mockCodes = mockCodes
        self.shouldFailNetwork = shouldFailNetwork

        if self.mockDomains.isEmpty {
            let ucb = InstitutionInfo(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "Universidad Católica Boliviana", slug: "ucb")
            let unam = InstitutionInfo(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "Universidad Nacional Autónoma de México", slug: "unam")
            self.mockDomains["ucb.edu.bo"] = ucb
            self.mockDomains["unam.mx"] = unam
            self.mockDomains["lectoria.edu"] = ucb

            self.mockCodes["UCB-2026-X9K2"] = MockCode(code: "UCB-2026-X9K2", institution: ucb, maxUses: 10, currentUses: 0)
            self.mockCodes["UNAM-EXPIRED"] = MockCode(code: "UNAM-EXPIRED", institution: unam, expiresAt: Date().addingTimeInterval(-86400))
            self.mockCodes["UNAM-DISABLED"] = MockCode(code: "UNAM-DISABLED", institution: unam, isActive: false)
            self.mockCodes["UNAM-FULL"] = MockCode(code: "UNAM-FULL", institution: unam, maxUses: 5, currentUses: 5)
        }
    }

    public func validateDomain(email: String) async throws -> InstitutionInfo {
        if shouldFailNetwork { throw InstitutionalAuthError.networkError }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let parts = trimmedEmail.components(separatedBy: "@")
        guard parts.count == 2 else { throw InstitutionalAuthError.invalidEmail }
        let domain = parts[1]

        if let inst = mockDomains[domain] {
            return inst
        }

        for (key, inst) in mockDomains {
            if domain.hasSuffix(key) || key.hasSuffix(domain) {
                return inst
            }
        }

        throw InstitutionalAuthError.domainUnauthorized(domain: domain)
    }

    public func inspectAccessCode(code: String) async throws -> InstitutionInfo {
        if shouldFailNetwork { throw InstitutionalAuthError.networkError }

        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        guard let item = mockCodes[cleanCode] else {
            throw InstitutionalAuthError.codeNotFound
        }

        if !item.isActive {
            throw InstitutionalAuthError.codeDeactivated
        }

        if let expiresAt = item.expiresAt, expiresAt < Date() {
            throw InstitutionalAuthError.codeExpired
        }

        if item.currentUses >= item.maxUses {
            throw InstitutionalAuthError.codeMaxUsesReached
        }

        return item.institution
    }

    public func requestInstitutionalOTP(code: String, email: String) async throws -> AccessCodeValidationResult {
        if shouldFailNetwork { throw InstitutionalAuthError.networkError }

        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard let item = mockCodes[cleanCode] else {
            throw InstitutionalAuthError.codeNotFound
        }

        if !item.isActive {
            throw InstitutionalAuthError.codeDeactivated
        }

        if let expiresAt = item.expiresAt, expiresAt < Date() {
            throw InstitutionalAuthError.codeExpired
        }

        if item.currentUses >= item.maxUses {
            throw InstitutionalAuthError.codeMaxUsesReached
        }

        // Validar dominio
        _ = try await validateDomain(email: cleanEmail)

        let ticket = "mock_ticket_\(UUID().uuidString)"
        
        // Simular creación del ticket en estado pending
        var mockTicket = MockTicket(id: ticket, institutionID: item.institution.id, code: item, status: "pending", email: cleanEmail)
        mockTickets[ticket] = mockTicket

        if shouldFailOTPSend {
            // Revocar ticket inmediatamente
            mockTicket.status = "revoked"
            mockTickets[ticket] = mockTicket
            throw InstitutionalAuthError.serviceError(message: "Fallo en envío de OTP")
        }

        // Activar el ticket
        mockTicket.status = "active"
        mockTickets[ticket] = mockTicket

        return AccessCodeValidationResult(validation_ticket: ticket, institution: item.institution)
    }

    public func claimMembershipByDomain(email: String) async throws {
        if shouldFailNetwork { throw InstitutionalAuthError.networkError }
        claimedMemberships.append((email: email, ticketOrDomain: "domain"))
    }

    public func claimMembershipByTicket(ticket: String) async throws {
        if shouldFailNetwork { throw InstitutionalAuthError.networkError }

        guard let mockData = mockTickets[ticket] else {
            throw InstitutionalAuthError.serviceError(message: "Ticket de validación no encontrado o no autorizado")
        }

        if mockData.status == "used" {
            throw InstitutionalAuthError.serviceError(message: "Este ticket ya fue utilizado.")
        }
        if mockData.status == "revoked" {
            throw InstitutionalAuthError.serviceError(message: "Este ticket ya fue revocado.")
        }
        if mockData.status == "pending" {
            throw InstitutionalAuthError.serviceError(message: "Este ticket no se encuentra activo.")
        }

        if let initialCode = mockData.code, var currentCode = mockCodes[initialCode.code] {
            if currentCode.currentUses >= currentCode.maxUses {
                throw InstitutionalAuthError.codeMaxUsesReached
            }
            currentCode.currentUses += 1
            mockCodes[initialCode.code] = currentCode
        }

        var updatedTicket = mockData
        updatedTicket.status = "used"
        mockTickets[ticket] = updatedTicket

        claimedMemberships.append((email: mockData.email, ticketOrDomain: ticket))
    }
}
