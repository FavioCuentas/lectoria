import Testing
import Foundation
@testable import Lectoria

// MARK: - DeviceManagementTests

@MainActor
struct DeviceManagementTests {
    private let mockSub: MockSubscriptionService
    private let dependencies: AppDependencies

    init() {
        self.mockSub = MockSubscriptionService()
        self.dependencies = AppDependencies(
            modelContainer: ModelContainerFactory.create(isStoredInMemoryOnly: true),
            authService: MockAuthService(),
            subscriptionService: mockSub
        )
    }

    @Test("Keychain persistent device_id generation")
    func testKeychainDeviceIDPersistence() async throws {
        let service = DeviceManagementService(entitlementService: dependencies.entitlementService)
        let id1 = service.getOrCreateDeviceID()
        let id2 = service.getOrCreateDeviceID()

        #expect(!id1.isEmpty)
        #expect(id1 == id2)
    }

    @Test("RegisteredDevice 30-day removal policy rule")
    func testRegisteredDeviceRemovalPolicy() async throws {
        let newDevice = RegisteredDevice(
            id: UUID().uuidString,
            name: "Nuevo iPhone",
            platform: "iOS",
            addedAt: Date(),
            isCurrentDevice: false
        )

        #expect(newDevice.canBeRemoved == false)
        #expect(newDevice.daysUntilRemovalAllowed == 30)

        // Device added 31 days ago
        let oldDate = Calendar.current.date(byAdding: .day, value: -31, to: Date())!
        let oldDevice = RegisteredDevice(
            id: UUID().uuidString,
            name: "iPhone Antiguo",
            platform: "iOS",
            addedAt: oldDate,
            isCurrentDevice: false
        )

        #expect(oldDevice.canBeRemoved == true)
        #expect(oldDevice.daysUntilRemovalAllowed == 0)
    }

    @Test("Device registration limit on Free plan (max 1 device)")
    func testFreePlanDeviceRegistrationLimit() async throws {
        mockSub.hasActiveSubscription = false
        let service = DeviceManagementService(entitlementService: dependencies.entitlementService)

        // Initial device registered
        let first = try await service.registerCurrentDevice()
        #expect(first.isCurrentDevice == true)

        let initialList = try await service.fetchRegisteredDevices()
        #expect(initialList.count == 1)
    }

    @Test("Device registration limit on Premium plan (max 3 devices)")
    func testPremiumPlanDeviceRegistrationLimit() async throws {
        mockSub.hasActiveSubscription = true
        let entitlementService = dependencies.entitlementService
        let currentEnts = await entitlementService.currentEntitlements()

        #expect(currentEnts.maximumDevices == 3)
    }

    @Test("Cannot remove current device error")
    func testCannotRemoveCurrentDevice() async throws {
        let service = DeviceManagementService(entitlementService: dependencies.entitlementService)
        let current = try await service.registerCurrentDevice()

        do {
            try await service.removeDevice(id: current.id)
            #expect(Bool(false), "Should have thrown currentDeviceCannotBeRemoved")
        } catch let error as DeviceManagementError {
            #expect(error.errorDescription?.contains("No puedes desvincular el dispositivo que estás usando actualmente") == true)
        }
    }
}
