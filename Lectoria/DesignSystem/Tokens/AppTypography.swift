import SwiftUI

// MARK: - AppTypography

/// Tokens tipográficos para Lectoria.
///
/// Interfaz: SF Pro (sistema) con pesos y tamaños definidos.
/// Lectura: New York (serif del sistema) con escala controlada.
///
/// Soporta Dynamic Type para la interfaz. El contenido de lectura
/// tiene su propia escala accesible, no vinculada directamente a
/// Dynamic Type para evitar conflictos con las preferencias del lector.
enum AppTypography {

    // MARK: - Interfaz (SF Pro via sistema)

    /// Título grande — pantallas principales.
    static let largeTitle: Font = .largeTitle.weight(.bold)

    /// Título — encabezados de sección.
    static let title: Font = .title2.weight(.semibold)

    /// Título secundario.
    static let title2: Font = .title3.weight(.medium)

    /// Subtítulo.
    static let subtitle: Font = .subheadline.weight(.medium)

    /// Cuerpo — texto principal de interfaz.
    static let body: Font = .body

    /// Cuerpo con énfasis.
    static let bodyBold: Font = .body.weight(.semibold)

    /// Texto secundario, menor jerarquía.
    static let callout: Font = .callout

    /// Pie de página, metadatos.
    static let footnote: Font = .footnote

    /// Etiquetas mínimas, badges.
    static let caption: Font = .caption

    /// Caption con énfasis.
    static let captionBold: Font = .caption.weight(.semibold)

    // MARK: - Lectura (New York / Serif del sistema)

    /// Fuente de lectura — New York.
    /// El tamaño se controla desde las preferencias del lector.
    static func readerFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Fuente de lectura para interfaz de controles del lector.
    static let readerUI: Font = .system(.callout, design: .serif)

    // MARK: - Escala de lectura

    /// Tamaños de fuente disponibles para el lector.
    static let readerFontSizes: [CGFloat] = [14, 16, 18, 20, 22, 24, 28, 32]

    /// Tamaño por defecto para lectura.
    static let defaultReaderFontSize: CGFloat = 18

    /// Índice del tamaño por defecto en `readerFontSizes`.
    static let defaultReaderFontSizeIndex: Int = 2

    // MARK: - Interlineado

    /// Opciones de interlineado relativo al tamaño de fuente.
    static let lineSpacingOptions: [CGFloat] = [1.0, 1.2, 1.4, 1.6, 1.8, 2.0]

    /// Interlineado por defecto.
    static let defaultLineSpacing: CGFloat = 1.4
}
