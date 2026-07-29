import Foundation
import UIKit
import Observation

// MARK: - DeviceManagementError

public enum DeviceManagementError: LocalizedError, Sendable {
    case limitExceeded(max: Int)
    case removalNotAllowed(daysRemaining: Int)
    case deviceNotFound
    case currentDeviceCannotBeRemoved

    public var errorDescription: String? {
        switch self {
        case .limitExceeded(let max):
            return String(localized: "Has alcanzado el límite de \(max) dispositivo(s) para tu plan actual. Puedes desvincular un dispositivo existente si han transcurrido 30 días.", comment: "Device limit error")
        case .removalNotAllowed(let daysRemaining):
            return String(localized: "Deben transcurrir al menos 30 días desde el registro para desvincular este dispositivo. Faltan \(daysRemaining) día(s).", comment: "Device removal error")
        case .deviceNotFound:
            return String(localized: "El dispositivo no fue encontrado.", comment: "Device error")
        case .currentDeviceCannotBeRemoved:
            return String(localized: "No puedes desvincular el dispositivo que estás usando actualmente.", comment: "Device error")
        }
    }
}

// MARK: - DeviceManagementService

/// Servicio centralizado para administrar el UUID persistente en Keychain, el registro de dispositivos
/// y el control de límites por plan (1 en Free / 3 en Premium) con la regla de 30 días.
@Observable
public final class DeviceManagementService: @unchecked Sendable {
    private static let deviceIDKeychainKey = "com.lectoria.app.installation_device_id"

    private let entitlementService: (any EntitlementService)?
    private var mockRegisteredDevices: [RegisteredDevice] = []

    public init(entitlementService: (any EntitlementService)? = nil) {
        self.entitlementService = entitlementService
    }

    /// Recupera o genera un UUID de instalación persistente en el Keychain.
    public func getOrCreateDeviceID() -> String {
        if let data = KeychainHelper.load(key: Self.deviceIDKeychainKey),
           let existingID = String(data: data, encoding: .utf8) {
            return existingID
        }

        let newID = UUID().uuidString
        if let newIDData = newID.data(using: .utf8) {
            KeychainHelper.save(key: Self.deviceIDKeychainKey, data: newIDData)
        }
        return newID
    }

    /// Obtiene la lista de dispositivos registrados para la cuenta actual.
    @MainActor
    public func fetchRegisteredDevices() async throws -> [RegisteredDevice] {
        let currentID = getOrCreateDeviceID()
        let currentName = UIDevice.current.name.isEmpty ? "iPhone" : UIDevice.current.name
        let currentPlatform = UIDevice.current.userInterfaceIdiom == .pad ? "iPadOS" : "iOS"

        if mockRegisteredDevices.isEmpty {
            let current = RegisteredDevice(
                id: currentID,
                name: currentName,
                platform: currentPlatform,
                addedAt: Date(),
                lastActiveAt: Date(),
                isCurrentDevice: true
            )
            mockRegisteredDevices = [current]
        }

        // Marcar el dispositivo actual
        return mockRegisteredDevices.map { dev in
            var d = dev
            d.isCurrentDevice = (dev.id == currentID)
            return d
        }
    }

    /// Registra el dispositivo actual verificando los límites del plan (1 Free / 3 Premium).
    @MainActor
    public func registerCurrentDevice() async throws -> RegisteredDevice {
        let devices = try await fetchRegisteredDevices()
        let currentID = getOrCreateDeviceID()

        // Si ya está registrado, actualizar lastActiveAt
        if let idx = devices.firstIndex(where: { $0.id == currentID }) {
            var updated = devices[idx]
            updated.lastActiveAt = Date()
            mockRegisteredDevices[idx] = updated
            return updated
        }

        // Determinar límite máximo permitido por Entitlements
        let maxDevices: Int
        if let entitlementService {
            let currentEnts = await entitlementService.currentEntitlements()
            maxDevices = currentEnts.maximumDevices
        } else {
            maxDevices = 1
        }

        if devices.count >= maxDevices {
            throw DeviceManagementError.limitExceeded(max: maxDevices)
        }

        let currentName = UIDevice.current.name.isEmpty ? "iPhone" : UIDevice.current.name
        let currentPlatform = UIDevice.current.userInterfaceIdiom == .pad ? "iPadOS" : "iOS"

        let newDevice = RegisteredDevice(
            id: currentID,
            name: currentName,
            platform: currentPlatform,
            addedAt: Date(),
            lastActiveAt: Date(),
            isCurrentDevice: true
        )

        mockRegisteredDevices.append(newDevice)
        return newDevice
    }

    /// Desvincula un dispositivo verificando la regla de 30 días de antigüedad.
    public func removeDevice(id: String) async throws {
        let currentID = getOrCreateDeviceID()
        if id == currentID {
            throw DeviceManagementError.currentDeviceCannotBeRemoved
        }

        guard let idx = mockRegisteredDevices.firstIndex(where: { $0.id == id }) else {
            throw DeviceManagementError.deviceNotFound
        }

        let device = mockRegisteredDevices[idx]
        if !device.canBeRemoved {
            throw DeviceManagementError.removalNotAllowed(daysRemaining: device.daysUntilRemovalAllowed)
        }

        mockRegisteredDevices.remove(at: idx)
    }
}
