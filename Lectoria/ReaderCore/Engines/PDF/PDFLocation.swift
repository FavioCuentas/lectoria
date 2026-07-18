import Foundation

// MARK: - PDFLocation

/// Representa la posición actual de lectura en un documento PDF.
struct PDFLocation: Codable, Sendable, Hashable {
    let pageIndex: Int
    let totalPages: Int?
    let pageLabel: String?
    let selectionBounds: [Double]?

    nonisolated init(pageIndex: Int, totalPages: Int? = nil, pageLabel: String? = nil, selectionBounds: [Double]? = nil) {
        self.pageIndex = pageIndex
        self.totalPages = totalPages
        self.pageLabel = pageLabel
        self.selectionBounds = selectionBounds
    }

    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case pageIndex
        case totalPages
        case pageLabel
        case selectionBounds
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.pageIndex = try container.decode(Int.self, forKey: .pageIndex)
        self.totalPages = try container.decodeIfPresent(Int.self, forKey: .totalPages)
        self.pageLabel = try container.decodeIfPresent(String.self, forKey: .pageLabel)
        self.selectionBounds = try container.decodeIfPresent([Double].self, forKey: .selectionBounds)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pageIndex, forKey: .pageIndex)
        try container.encodeIfPresent(totalPages, forKey: .totalPages)
        try container.encodeIfPresent(pageLabel, forKey: .pageLabel)
        try container.encodeIfPresent(selectionBounds, forKey: .selectionBounds)
    }
}
