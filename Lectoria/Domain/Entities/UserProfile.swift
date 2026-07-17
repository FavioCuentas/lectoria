import Foundation

// MARK: - UserProfile

/// Representa el perfil de cuenta de un usuario autenticado en Lectoria.
public struct UserProfile: Codable, Sendable, Identifiable, Hashable {
    public var id: String
    public let email: String?
    public let fullName: String?
    public let createdAt: Date

    public init(
        id: String,
        email: String?,
        fullName: String?,
        createdAt: Date = .now
    ) {
        self.id = id
        self.email = email
        self.fullName = fullName
        self.createdAt = createdAt
    }
}
