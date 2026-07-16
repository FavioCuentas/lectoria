import SwiftUI

// MARK: - AppSpacing

/// Tokens de espaciado para mantener ritmo visual consistente.
///
/// Usar estos valores en lugar de números arbitrarios en las vistas.
enum AppSpacing {
    /// 2pt — espaciado mínimo.
    static let xxs: CGFloat = 2
    /// 4pt — micro-separaciones.
    static let xs: CGFloat = 4
    /// 8pt — entre elementos compactos.
    static let sm: CGFloat = 8
    /// 12pt — padding interno de componentes.
    static let md: CGFloat = 12
    /// 16pt — padding estándar.
    static let lg: CGFloat = 16
    /// 20pt — separación entre secciones.
    static let xl: CGFloat = 20
    /// 24pt — separación entre bloques.
    static let xxl: CGFloat = 24
    /// 32pt — separación grande.
    static let xxxl: CGFloat = 32
    /// 48pt — espaciado máximo.
    static let huge: CGFloat = 48

    /// Padding horizontal de pantalla.
    static let screenHorizontal: CGFloat = 20

    /// Padding vertical de pantalla.
    static let screenVertical: CGFloat = 16
}

// MARK: - AppRadius

/// Tokens de radio de esquina para componentes.
enum AppRadius {
    /// 4pt — elementos mínimos (badges, chips).
    static let xs: CGFloat = 4
    /// 8pt — inputs, campos.
    static let sm: CGFloat = 8
    /// 12pt — cards, botones.
    static let md: CGFloat = 12
    /// 16pt — cards grandes, sheets.
    static let lg: CGFloat = 16
    /// 20pt — modals.
    static let xl: CGFloat = 20
    /// Completamente redondeado (pills).
    static let full: CGFloat = 999
}

// MARK: - AppShadow

/// Tokens de sombra para dar profundidad a componentes.
///
/// Las sombras se adaptan al tema actual para mantener
/// contraste adecuado en modo claro y oscuro.
enum AppShadow {
    /// Sombra sutil — apenas perceptible, estilo minimalista.
    static func subtle(for theme: AppTheme) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        switch theme {
        case .light:
            (Color.black.opacity(0.04), 2, 0, 1)
        case .dark:
            (Color.black.opacity(0.20), 2, 0, 1)
        case .sepia:
            (Color.brown.opacity(0.05), 2, 0, 1)
        }
    }

    /// Sombra media — solo para elementos flotantes.
    static func medium(for theme: AppTheme) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        switch theme {
        case .light:
            (Color.black.opacity(0.06), 6, 0, 3)
        case .dark:
            (Color.black.opacity(0.30), 6, 0, 3)
        case .sepia:
            (Color.brown.opacity(0.08), 6, 0, 3)
        }
    }

    /// Sombra prominente — modals y dropdowns.
    static func prominent(for theme: AppTheme) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        switch theme {
        case .light:
            (Color.black.opacity(0.10), 12, 0, 6)
        case .dark:
            (Color.black.opacity(0.40), 12, 0, 6)
        case .sepia:
            (Color.brown.opacity(0.12), 12, 0, 6)
        }
    }
}
