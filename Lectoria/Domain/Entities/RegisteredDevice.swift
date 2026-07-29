import Foundation

// MARK: - RegisteredDevice

/// Modelo de dominio que representa un dispositivo registrado y autorizado en la cuenta del usuario.
public struct RegisteredDevice: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var platform: String
    public var addedAt: Date
    public var lastActiveAt: Date
    public var isCurrentDevice: Bool

    public init(
        id: String,
        name: String,
        platform: String,
        addedAt: Date = Date(),
        lastActiveAt: Date = Date(),
        isCurrentDevice: Bool = false
    ) {
        self.id = id
        self.name = name
        self.platform = platform
        self.addedAt = addedAt
        self.lastActiveAt = lastActiveAt
        self.isCurrentDevice = isCurrentDevice
    }

    /// Determina si el dispositivo cumple la regla de al menos 30 días transcurridos para poder ser desvinculado.
    public var canBeRemoved: Bool {
        let days = Calendar.current.dateComponents([.day], from: addedAt, to: Date()).day ?? 0
        return days >= 30
    }

    /// Días restantes antes de poder desvincular el dispositivo si aún no cumple los 30 días.
    public var daysUntilRemovalAllowed: Int {
        let days = Calendar.current.dateComponents([.day], from: addedAt, to: Date()).day ?? 0
        return max(0, 30 - days)
    }
}
