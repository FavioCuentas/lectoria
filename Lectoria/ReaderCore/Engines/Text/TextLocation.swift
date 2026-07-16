import Foundation

// MARK: - TextLocation

/// Representa la posición actual de lectura en un documento de texto plano o Markdown.
struct TextLocation: Codable, Sendable, Hashable {
    let blockIndex: Int
    let characterOffset: Int
    let percentage: Double

    nonisolated init(blockIndex: Int, characterOffset: Int = 0, percentage: Double = 0.0) {
        self.blockIndex = blockIndex
        self.characterOffset = characterOffset
        self.percentage = percentage
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case blockIndex
        case characterOffset
        case percentage
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.blockIndex = try container.decode(Int.self, forKey: .blockIndex)
        self.characterOffset = try container.decode(Int.self, forKey: .characterOffset)
        self.percentage = try container.decode(Double.self, forKey: .percentage)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(blockIndex, forKey: .blockIndex)
        try container.encode(characterOffset, forKey: .characterOffset)
        try container.encode(percentage, forKey: .percentage)
    }
}
