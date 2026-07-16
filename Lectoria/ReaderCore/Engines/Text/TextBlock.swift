import Foundation

// MARK: - TextBlock

/// Representa un fragmento estructurado de texto (un párrafo, un encabezado, una lista, etc.).
struct TextBlock: Identifiable, Sendable, Hashable {
    let id: UUID
    let index: Int
    let type: BlockType
    let rawText: String

    init(id: UUID = UUID(), index: Int, type: BlockType, rawText: String) {
        self.id = id
        self.index = index
        self.type = type
        self.rawText = rawText
    }
    
    enum BlockType: Sendable, Hashable {
        case heading(text: String, level: Int)
        case paragraph(text: String)
        case blockquote(text: String)
        case listItem(text: String)
        case codeBlock(code: String, language: String?)
    }
}
