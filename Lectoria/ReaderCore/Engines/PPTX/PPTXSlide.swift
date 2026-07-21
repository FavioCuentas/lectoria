import Foundation

// MARK: - PPTXSlide

/// Representa una diapositiva extraída de un archivo PPTX.
struct PPTXSlide: Identifiable, Sendable {
    let id: UUID
    let slideNumber: Int
    let title: String?
    let bodyTexts: [String]
    let speakerNotes: String?

    init(
        id: UUID = UUID(),
        slideNumber: Int,
        title: String? = nil,
        bodyTexts: [String] = [],
        speakerNotes: String? = nil
    ) {
        self.id = id
        self.slideNumber = slideNumber
        self.title = title
        self.bodyTexts = bodyTexts
        self.speakerNotes = speakerNotes
    }

    /// Indica si la diapositiva contiene algún contenido textual visible.
    var hasContent: Bool {
        title != nil || !bodyTexts.isEmpty
    }
}
