import Foundation
import CoreGraphics

// MARK: - AnnotationSourceType

public enum AnnotationSourceType: String, Codable, Sendable {
    case realText
    case ocr
    case manualPin
}

// MARK: - SelectionGeometry

public struct SelectionGeometry: Codable, Sendable, Hashable {
    public let x: CGFloat
    public let y: CGFloat
    public let width: CGFloat
    public let height: CGFloat

    public init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public init(rect: CGRect) {
        self.x = rect.origin.x
        self.y = rect.origin.y
        self.width = rect.size.width
        self.height = rect.size.height
    }

    public var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

// MARK: - PresentationAnnotation

/// Modelo normalizado de datos para anotaciones, selecciones de texto y resaltados por diapositiva.
public struct PresentationAnnotation: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let documentID: String
    public let documentHash: String
    public let slideID: String
    public let slideIndex: Int
    public let selectedText: String
    public let normalizedText: String?
    public let sourceType: AnnotationSourceType
    public let selectionGeometry: SelectionGeometry?
    public let categoryID: String?
    public let highlightColor: String?
    public let userComment: String?
    public let sourceLanguage: String?
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID = UUID(),
        documentID: String,
        documentHash: String = "",
        slideID: String,
        slideIndex: Int,
        selectedText: String,
        normalizedText: String? = nil,
        sourceType: AnnotationSourceType = .realText,
        selectionGeometry: SelectionGeometry? = nil,
        categoryID: String? = "Importante",
        highlightColor: String? = nil,
        userComment: String? = nil,
        sourceLanguage: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.documentID = documentID
        self.documentHash = documentHash
        self.slideID = slideID
        self.slideIndex = slideIndex
        self.selectedText = selectedText
        self.normalizedText = normalizedText ?? selectedText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.sourceType = sourceType
        self.selectionGeometry = selectionGeometry
        self.categoryID = categoryID
        self.highlightColor = highlightColor
        self.userComment = userComment
        self.sourceLanguage = sourceLanguage
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
