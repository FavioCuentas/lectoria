import UIKit
import Observation

// MARK: - Herramientas

enum PencilTool: String, CaseIterable {
    case text, pen, marker, eraser
}

enum PencilWidth: Int, CaseIterable {
    case thin, medium, thick
}

enum PencilPenColor: Equatable {
    case category(HighlightCategory)
    case black
}

// MARK: - PencilPaletteState

/// Estado de la paleta del lápiz (solo iPad): herramienta, color y grosor, recordados entre sesiones.
@MainActor
@Observable
final class PencilPaletteState {
    @ObservationIgnored private let defaults: UserDefaults
    let availableTools: [PencilTool]

    var tool: PencilTool { didSet { defaults.set(tool.rawValue, forKey: Keys.tool) } }
    var category: HighlightCategory { didSet { defaults.set(category.rawValue, forKey: Keys.category) } }
    var penColor: PencilPenColor { didSet { defaults.set(Self.encode(penColor), forKey: Keys.penColor) } }
    var width: PencilWidth { didSet { defaults.set(width.rawValue, forKey: Keys.width) } }

    private enum Keys {
        static let tool = "pencil.tool"
        static let category = "pencil.category"
        static let penColor = "pencil.penColor"
        static let width = "pencil.width"
    }

    init(publicationType: PublicationType, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let tools = Self.tools(for: publicationType)
        availableTools = tools

        let savedTool = defaults.string(forKey: Keys.tool).flatMap(PencilTool.init(rawValue:)) ?? .text
        tool = tools.contains(savedTool) ? savedTool : .text
        category = defaults.string(forKey: Keys.category).flatMap(HighlightCategory.init(rawValue:))
            .flatMap { HighlightCategory.userSelectableCases.contains($0) ? $0 : nil } ?? .mainIdea
        penColor = defaults.string(forKey: Keys.penColor).flatMap(Self.decode) ?? .category(.mainIdea)
        width = PencilWidth(rawValue: defaults.object(forKey: Keys.width) as? Int ?? -1) ?? .medium
    }

    /// Pluma, marcador y borrador solo tienen sentido en contenido de diseño fijo (PDF y presentaciones).
    static func tools(for type: PublicationType) -> [PencilTool] {
        switch type {
        case .pdf, .pptx: [.text, .pen, .marker, .eraser]
        case .epub, .txt, .markdown, .pastedText: [.text]
        }
    }

    /// Grosor del trazo en puntos; 0 para las herramientas que no dibujan.
    func strokeWidth() -> CGFloat {
        switch tool {
        case .pen: [2, 4, 7][width.rawValue]
        case .marker: [12, 20, 30][width.rawValue]
        case .text, .eraser: 0
        }
    }

    /// Color del trazo libre: la pluma es opaca y el marcador semitransparente.
    func inkColor() -> UIColor {
        switch tool {
        case .marker:
            return Self.color(for: category).withAlphaComponent(0.35)
        default:
            switch penColor {
            case .black: return .black
            case .category(let category): return Self.color(for: category)
            }
        }
    }

    /// Mismos tonos que los destacados del lector PDF.
    static func color(for category: HighlightCategory) -> UIColor {
        switch category {
        case .mainIdea: UIColor(red: 0.30, green: 0.55, blue: 0.80, alpha: 1)
        case .question: UIColor(red: 0.55, green: 0.38, blue: 0.75, alpha: 1)
        case .evidence: UIColor(red: 0.25, green: 0.65, blue: 0.45, alpha: 1)
        case .action: UIColor(red: 0.85, green: 0.47, blue: 0.34, alpha: 1)
        case .quote: UIColor(red: 0.80, green: 0.42, blue: 0.55, alpha: 1)
        default: UIColor(red: 0.95, green: 0.80, blue: 0.30, alpha: 1)
        }
    }

    private static func encode(_ color: PencilPenColor) -> String {
        switch color {
        case .black: "black"
        case .category(let category): category.rawValue
        }
    }

    private static func decode(_ raw: String) -> PencilPenColor? {
        if raw == "black" { return .black }
        return HighlightCategory(rawValue: raw).map(PencilPenColor.category)
    }
}
