import Foundation

// MARK: - Highlight

/// Representa un texto subrayado en una publicación, con su rango, contexto y categoría de estudio.
public struct Highlight: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let publicationID: UUID
    
    /// Posición física codificada (Locator, rango de caracteres, etc.).
    public var anchor: String
    
    /// El texto exacto seleccionado por el usuario.
    public var selectedText: String
    
    /// Fragmento de texto anterior para contextualización.
    public var contextBefore: String?
    
    /// Fragmento de texto posterior para contextualización.
    public var contextAfter: String?
    
    /// Categoría opcional definida por el usuario para organizar su conocimiento (ej. "Idea principal", "Vocabulario").
    public var category: String?
    
    /// Identificador del color en el Design System (ej. "yellow", "coral").
    public var colorToken: String
    
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        publicationID: UUID,
        anchor: String,
        selectedText: String,
        contextBefore: String? = nil,
        contextAfter: String? = nil,
        category: String? = nil,
        colorToken: String = "yellow",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.publicationID = publicationID
        self.anchor = anchor
        self.selectedText = selectedText
        self.contextBefore = contextBefore
        self.contextAfter = contextAfter
        self.category = category
        self.colorToken = colorToken
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
public enum HighlightCategory: String, Codable, Sendable, CaseIterable {
    case mainIdea = "Idea principal"
    case question = "Duda"
    case evidence = "Evidencia"
    case action = "Acción"
    case quote = "Cita"
}
