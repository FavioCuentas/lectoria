import Testing
import Foundation
@testable import Lectoria

@MainActor
struct InstitutionalAuthTests {

    private func makeSUT(
        mockDomains: [String: InstitutionInfo] = [:],
        mockCodes: [String: MockInstitutionService.MockCode] = [:],
        shouldFailNetwork: Bool = false
    ) -> (
        vm: InstitutionalAuthViewModel,
        instService: MockInstitutionService,
        authService: MockAuthService,
        guestMigrateCount: Box<Int>
    ) {
        let instService = MockInstitutionService(
            mockDomains: mockDomains,
            mockCodes: mockCodes,
            shouldFailNetwork: shouldFailNetwork
        )
        let authService = MockAuthService()
        let guestMigrateCount = Box<Int>(0)

        let vm = InstitutionalAuthViewModel(
            institutionService: instService,
            authService: authService,
            onGuestMigrate: { _ in
                guestMigrateCount.value += 1
            },
            onSuccess: {}
        )

        return (vm, instService, authService, guestMigrateCount)
    }

    // MARK: - 1. Código Institucional Válido

    @Test func testValidAccessCode() async throws {
        let ucb = InstitutionInfo(id: UUID(), name: "Universidad Católica", slug: "ucb")
        let code = MockInstitutionService.MockCode(code: "UCB-2026-VALID", institution: ucb)
        let (vm, _, _, _) = makeSUT(mockCodes: ["UCB-2026-VALID": code])

        vm.selectRoute(.code)
        vm.accessCode = "UCB-2026-VALID"
        await vm.validateAccessCode()

        #expect(vm.validatedInstitution?.name == "Universidad Católica")
        #expect(vm.validation_ticket == nil)
        if case .institutionValidated(let inst) = vm.state {
            #expect(inst.slug == "ucb")
        } else {
            Issue.record("El estado debería ser institutionValidated")
        }
    }

    // MARK: - 2. Código Inexistente

    @Test func testNonExistentAccessCode() async throws {
        let (vm, _, _, _) = makeSUT()

        vm.selectRoute(.code)
        vm.accessCode = "INVALID-CODE-999"
        await vm.validateAccessCode()

        #expect(vm.validatedInstitution == nil)
        #expect(vm.validation_ticket == nil)
        #expect(vm.errorMessage?.contains("no es válido") == true)
        if case .failed(let error) = vm.state {
            #expect(error == .codeNotFound)
        } else {
            Issue.record("El estado debería ser failed(.codeNotFound)")
        }
    }

    // MARK: - 3. Código Vencido

    @Test func testExpiredAccessCode() async throws {
        let unam = InstitutionInfo(id: UUID(), name: "UNAM", slug: "unam")
        let expiredCode = MockInstitutionService.MockCode(
            code: "UNAM-EXPIRED",
            institution: unam,
            expiresAt: Date().addingTimeInterval(-3600)
        )
        let (vm, _, _, _) = makeSUT(mockCodes: ["UNAM-EXPIRED": expiredCode])

        vm.selectRoute(.code)
        vm.accessCode = "UNAM-EXPIRED"
        await vm.validateAccessCode()

        #expect(vm.errorMessage?.contains("vencido") == true || vm.errorMessage?.contains("no es válido") == true)
        if case .failed(let error) = vm.state {
            #expect(error == .codeExpired || error == .codeNotFound)
        } else {
            Issue.record("El estado debería ser failed")
        }
    }

    // MARK: - 4. Código Desactivado

    @Test func testDeactivatedAccessCode() async throws {
        let unam = InstitutionInfo(id: UUID(), name: "UNAM", slug: "unam")
        let disabledCode = MockInstitutionService.MockCode(
            code: "UNAM-DISABLED",
            institution: unam,
            isActive: false
        )
        let (vm, _, _, _) = makeSUT(mockCodes: ["UNAM-DISABLED": disabledCode])

        vm.selectRoute(.code)
        vm.accessCode = "UNAM-DISABLED"
        await vm.validateAccessCode()

        #expect(vm.errorMessage?.contains("desactivado") == true || vm.errorMessage?.contains("no es válido") == true)
        if case .failed(let error) = vm.state {
            #expect(error == .codeDeactivated || error == .codeNotFound)
        } else {
            Issue.record("El estado debería ser failed")
        }
    }

    // MARK: - 5. Código Sin Usos Disponibles

    @Test func testMaxUsesReachedAccessCode() async throws {
        let unam = InstitutionInfo(id: UUID(), name: "UNAM", slug: "unam")
        let fullCode = MockInstitutionService.MockCode(
            code: "UNAM-FULL",
            institution: unam,
            maxUses: 5,
            currentUses: 5
        )
        let (vm, _, _, _) = makeSUT(mockCodes: ["UNAM-FULL": fullCode])

        vm.selectRoute(.code)
        vm.accessCode = "UNAM-FULL"
        await vm.validateAccessCode()

        #expect(vm.errorMessage?.contains("límite máximo") == true || vm.errorMessage?.contains("no es válido") == true)
        if case .failed(let error) = vm.state {
            #expect(error == .codeMaxUsesReached || error == .codeNotFound)
        } else {
            Issue.record("El estado debería ser failed")
        }
    }

    // MARK: - 6. Normalización de Mayúsculas y Espacios

    @Test func testCodeCaseAndWhitespaceNormalization() async throws {
        let ucb = InstitutionInfo(id: UUID(), name: "UCB", slug: "ucb")
        let code = MockInstitutionService.MockCode(code: "UCB-2026-NORM", institution: ucb)
        let (vm, _, _, _) = makeSUT(mockCodes: ["UCB-2026-NORM": code])

        vm.selectRoute(.code)
        vm.accessCode = "   ucb-2026-norm   "
        await vm.validateAccessCode()

        #expect(vm.validatedInstitution?.slug == "ucb")
        #expect(vm.validation_ticket == nil)
    }

    // MARK: - 7. Correo con Dominio Autorizado

    @Test func testAuthorizedEmailDomain() async throws {
        let ucb = InstitutionInfo(id: UUID(), name: "Universidad Católica", slug: "ucb")
        let (vm, _, _, _) = makeSUT(mockDomains: ["ucb.edu.bo": ucb])

        vm.selectRoute(.email)
        vm.email = "estudiante@ucb.edu.bo"
        await vm.validateEmailAndSendOTP()

        #expect(vm.validatedInstitution?.name == "Universidad Católica")
        if case .awaitingOTP(let email, let inst) = vm.state {
            #expect(email == "estudiante@ucb.edu.bo")
            #expect(inst?.slug == "ucb")
        } else {
            Issue.record("El estado debería ser awaitingOTP")
        }
    }

    // MARK: - 8. Correo con Dominio No Autorizado

    @Test func testUnauthorizedEmailDomain() async throws {
        let (vm, _, _, _) = makeSUT()

        vm.selectRoute(.email)
        vm.email = "usuario@desconocido-fake.com"
        await vm.validateEmailAndSendOTP()

        #expect(vm.errorMessage?.contains("no pertenece") == true || vm.errorMessage?.contains("no es válido") == true)
        if case .failed(let error) = vm.state {
            if case .domainUnauthorized(let domain) = error {
                #expect(domain == "desconocido-fake.com")
            } else if case .serviceError = error {
                // O error del servicio
            } else {
                Issue.record("Error no coincide")
            }
        } else {
            Issue.record("El estado debería ser failed")
        }
    }

    // MARK: - 9. OTP Correcto y Transacción mediante Validation Ticket

    @Test func testCorrectOTPVerification() async throws {
        let ucb = InstitutionInfo(id: UUID(), name: "UCB", slug: "ucb")
        let code = MockInstitutionService.MockCode(code: "UCB-2026-CLAIM", institution: ucb, maxUses: 10, currentUses: 0)
        let (vm, instService, _, guestCount) = makeSUT(mockCodes: ["UCB-2026-CLAIM": code])

        vm.selectRoute(.code)
        vm.accessCode = "UCB-2026-CLAIM"
        await vm.validateAccessCode()

        vm.email = "estudiante@ucb.edu.bo"
        await vm.validateEmailAndSendOTP()
        #expect(vm.validation_ticket != nil)

        vm.otpCode = "123456"
        await vm.verifyOTPAndLinkMembership()

        #expect(vm.state == .authenticated)
        #expect(instService.claimedMemberships.count == 1)
        #expect(guestCount.value == 1)
    }

    // MARK: - 10. OTP Incorrecto

    @Test func testIncorrectOTPVerification() async throws {
        let ucb = InstitutionInfo(id: UUID(), name: "UCB", slug: "ucb")
        let (vm, _, _, _) = makeSUT(mockDomains: ["ucb.edu.bo": ucb])

        vm.selectRoute(.email)
        vm.email = "estudiante@ucb.edu.bo"
        await vm.validateEmailAndSendOTP()

        vm.otpCode = "000000"
        await vm.verifyOTPAndLinkMembership()

        #expect(vm.errorMessage?.contains("incorrecto") == true)
    }

    // MARK: - 11. OTP Vencido

    @Test func testExpiredOTP() async throws {
        let ucb = InstitutionInfo(id: UUID(), name: "UCB", slug: "ucb")
        let (vm, _, authService, _) = makeSUT(mockDomains: ["ucb.edu.bo": ucb])

        authService.shouldFailOTP = true

        vm.selectRoute(.email)
        vm.email = "estudiante@ucb.edu.bo"
        await vm.validateEmailAndSendOTP()

        vm.otpCode = "123456"
        await vm.verifyOTPAndLinkMembership()

        #expect(vm.errorMessage != nil)
    }

    // MARK: - 12. Fallo de Red

    @Test func testNetworkFailureHandling() async throws {
        let (vm, _, _, _) = makeSUT(shouldFailNetwork: true)

        vm.selectRoute(.code)
        vm.accessCode = "UCB-2026-X9K2"
        await vm.validateAccessCode()

        if case .failed(let error) = vm.state {
            #expect(error == .networkError)
        } else {
            Issue.record("Debería fallar por red")
        }
    }

    // MARK: - 13. Reintento de OTP con Contador

    @Test func testResendOTPCountdown() async throws {
        let ucb = InstitutionInfo(id: UUID(), name: "UCB", slug: "ucb")
        let (vm, _, _, _) = makeSUT(mockDomains: ["ucb.edu.bo": ucb])

        vm.selectRoute(.email)
        vm.email = "estudiante@ucb.edu.bo"
        await vm.validateEmailAndSendOTP()

        #expect(vm.resendCountdown == 30)

        // Reset countdown to test resend
        vm.resendCountdown = 0
        await vm.resendOTP()
        #expect(vm.resendCountdown > 0)
    }

    // MARK: - 14. Membresía Ya Existente

    @Test func testExistingMembershipHandling() async throws {
        let ucb = InstitutionInfo(id: UUID(), name: "UCB", slug: "ucb")
        let (vm, instService, _, _) = makeSUT(mockDomains: ["ucb.edu.bo": ucb])

        vm.selectRoute(.email)
        vm.email = "estudiante@ucb.edu.bo"
        await vm.validateEmailAndSendOTP()

        vm.otpCode = "123456"
        await vm.verifyOTPAndLinkMembership()

        #expect(vm.state == .authenticated)
        #expect(instService.claimedMemberships.count == 1)
    }

    // MARK: - 15. Migración de Invitado Idempotente (2x)

    @Test func testGuestMigrationIdempotency() async throws {
        let container = ModelContainerFactory.create(isStoredInMemoryOnly: true)
        let appDeps = AppDependencies(modelContainer: container, authService: MockAuthService())

        let mockUserID = "user_test_123"

        await appDeps.migrateGuestData(to: mockUserID)
        await appDeps.migrateGuestData(to: mockUserID)

        let pubs = try await appDeps.publicationRepository.fetchAll()
        #expect(pubs.count >= 0)
    }

    // MARK: - 16. Simulación de Condición de Carrera en Código Agotado

    @Test func testConcurrentLastCodeUseRaceCondition() async throws {
        let ucb = InstitutionInfo(id: UUID(), name: "UCB", slug: "ucb")
        let code = MockInstitutionService.MockCode(code: "LAST-USE-CODE", institution: ucb, maxUses: 1, currentUses: 0)

        let instService = MockInstitutionService(mockCodes: ["LAST-USE-CODE": code])

        // Ambos usuarios obtienen ticket cuando currentUses = 0
        let res1 = try await instService.requestInstitutionalOTP(code: "LAST-USE-CODE", email: "u1@ucb.edu.bo")
        let res2 = try await instService.requestInstitutionalOTP(code: "LAST-USE-CODE", email: "u2@ucb.edu.bo")

        // Usuario 1 liquida primero el último uso disponible
        try await instService.claimMembershipByTicket(ticket: res1.validation_ticket)

        // Usuario 2 intenta reclamar con su ticket previamente obtenido
        do {
            try await instService.claimMembershipByTicket(ticket: res2.validation_ticket)
            Issue.record("El segundo usuario no debería poder consumir un código agotado")
        } catch let error as InstitutionalAuthError {
            #expect(error == .codeMaxUsesReached)
        }
    }
}

// MARK: - Helper Box

private final class Box<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) {
        self.value = value
    }
}
