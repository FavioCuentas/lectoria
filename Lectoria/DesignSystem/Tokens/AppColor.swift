import SwiftUI

// MARK: - AppColor

/// Tokens de color semánticos para Lectoria.
///
/// Paleta minimalista inspirada en Kindle y lectores premium.
/// Acento principal: coral rojizo de Claude (#DA7756).
/// Fondos limpios, tipografía clara, mínima decoración.
///
/// > No usar valores de color directos en las vistas.
/// > Siempre usar estos tokens.
enum AppColor {

    // MARK: - Fondos

    /// Fondo principal de la aplicación.
    static func background(for theme: AppTheme) -> Color {
        switch theme {
        case .light: Color(red: 0.98, green: 0.98, blue: 0.97)   // Blanco cálido casi puro
        case .dark: Color(red: 0.07, green: 0.07, blue: 0.08)     // Negro profundo
        case .sepia: Color(red: 0.96, green: 0.93, blue: 0.87)    // Papel antiguo suave
        }
    }

    /// Superficie elevada (cards, sheets, modals).
    static func surface(for theme: AppTheme) -> Color {
        switch theme {
        case .light: .white
        case .dark: Color(red: 0.11, green: 0.11, blue: 0.12)     // Carbón suave
        case .sepia: Color(red: 0.98, green: 0.95, blue: 0.90)    // Crema
        }
    }

    /// Superficie secundaria (agrupaciones, secciones).
    static func surfaceSecondary(for theme: AppTheme) -> Color {
        switch theme {
        case .light: Color(red: 0.96, green: 0.96, blue: 0.95)    // Gris fantasma
        case .dark: Color(red: 0.14, green: 0.14, blue: 0.15)     // Grafito oscuro
        case .sepia: Color(red: 0.94, green: 0.91, blue: 0.84)
        }
    }

    // MARK: - Textos

    /// Texto principal de alta legibilidad.
    static func textPrimary(for theme: AppTheme) -> Color {
        switch theme {
        case .light: Color(red: 0.10, green: 0.10, blue: 0.10)    // Negro suave
        case .dark: Color(red: 0.93, green: 0.92, blue: 0.90)     // Blanco cálido
        case .sepia: Color(red: 0.22, green: 0.16, blue: 0.10)    // Marrón tinta
        }
    }

    /// Texto secundario, menor énfasis.
    static func textSecondary(for theme: AppTheme) -> Color {
        switch theme {
        case .light: Color(red: 0.45, green: 0.45, blue: 0.45)    // Gris medio
        case .dark: Color(red: 0.62, green: 0.60, blue: 0.58)     // Gris cálido
        case .sepia: Color(red: 0.48, green: 0.40, blue: 0.32)    // Marrón medio
        }
    }

    /// Texto terciario, mínimo énfasis (placeholders, hints).
    static func textTertiary(for theme: AppTheme) -> Color {
        switch theme {
        case .light: Color(red: 0.65, green: 0.65, blue: 0.65)    // Gris claro
        case .dark: Color(red: 0.42, green: 0.40, blue: 0.38)     // Gris apagado
        case .sepia: Color(red: 0.60, green: 0.54, blue: 0.46)
        }
    }

    // MARK: - Acentos

    /// Color de acento principal: coral rojizo Claude (#DA7756).
    static func accent(for theme: AppTheme) -> Color {
        switch theme {
        case .light: Color(red: 0.855, green: 0.467, blue: 0.337)   // Coral Claude
        case .dark: Color(red: 0.900, green: 0.530, blue: 0.400)    // Coral luminoso
        case .sepia: Color(red: 0.820, green: 0.440, blue: 0.310)   // Coral cálido
        }
    }

    /// Color de acento secundario: coral suave para backgrounds.
    static func accentSecondary(for theme: AppTheme) -> Color {
        switch theme {
        case .light: Color(red: 0.855, green: 0.467, blue: 0.337).opacity(0.12)
        case .dark: Color(red: 0.900, green: 0.530, blue: 0.400).opacity(0.15)
        case .sepia: Color(red: 0.820, green: 0.440, blue: 0.310).opacity(0.12)
        }
    }

    // MARK: - Bordes y separadores

    /// Borde sutil para cards y contenedores.
    static func border(for theme: AppTheme) -> Color {
        switch theme {
        case .light: Color(red: 0.92, green: 0.92, blue: 0.91)    // Casi invisible
        case .dark: Color(red: 0.18, green: 0.18, blue: 0.19)
        case .sepia: Color(red: 0.88, green: 0.84, blue: 0.78)
        }
    }

    /// Separador para listas y secciones.
    static func separator(for theme: AppTheme) -> Color {
        border(for: theme).opacity(0.7)
    }

    // MARK: - Semánticos

    /// Éxito, completado.
    static func success(for theme: AppTheme) -> Color {
        switch theme {
        case .light: Color(red: 0.22, green: 0.60, blue: 0.40)
        case .dark: Color(red: 0.40, green: 0.75, blue: 0.55)
        case .sepia: Color(red: 0.28, green: 0.55, blue: 0.38)
        }
    }

    /// Advertencia.
    static func warning(for theme: AppTheme) -> Color {
        switch theme {
        case .light: Color(red: 0.85, green: 0.65, blue: 0.20)
        case .dark: Color(red: 0.92, green: 0.75, blue: 0.35)
        case .sepia: Color(red: 0.80, green: 0.60, blue: 0.22)
        }
    }

    /// Error, peligro.
    static func error(for theme: AppTheme) -> Color {
        switch theme {
        case .light: Color(red: 0.82, green: 0.28, blue: 0.25)
        case .dark: Color(red: 0.92, green: 0.42, blue: 0.38)
        case .sepia: Color(red: 0.75, green: 0.30, blue: 0.25)
        }
    }

    // MARK: - Colores de destacado (Highlight categories)

    /// Idea principal — azul suave.
    static func highlightMainIdea(for theme: AppTheme) -> Color {
        switch theme {
        case .light: Color(red: 0.30, green: 0.55, blue: 0.80).opacity(0.20)
        case .dark: Color(red: 0.35, green: 0.60, blue: 0.85).opacity(0.25)
        case .sepia: Color(red: 0.30, green: 0.50, blue: 0.72).opacity(0.20)
        }
    }

    /// Duda — púrpura suave.
    static func highlightQuestion(for theme: AppTheme) -> Color {
        switch theme {
        case .light: Color(red: 0.55, green: 0.38, blue: 0.75).opacity(0.20)
        case .dark: Color(red: 0.65, green: 0.48, blue: 0.85).opacity(0.25)
        case .sepia: Color(red: 0.52, green: 0.35, blue: 0.68).opacity(0.20)
        }
    }

    /// Evidencia — verde suave.
    static func highlightEvidence(for theme: AppTheme) -> Color {
        switch theme {
        case .light: Color(red: 0.25, green: 0.65, blue: 0.45).opacity(0.20)
        case .dark: Color(red: 0.35, green: 0.75, blue: 0.55).opacity(0.25)
        case .sepia: Color(red: 0.28, green: 0.58, blue: 0.42).opacity(0.20)
        }
    }

    /// Acción — coral suave (matching accent).
    static func highlightAction(for theme: AppTheme) -> Color {
        switch theme {
        case .light: Color(red: 0.85, green: 0.47, blue: 0.34).opacity(0.20)
        case .dark: Color(red: 0.90, green: 0.53, blue: 0.40).opacity(0.25)
        case .sepia: Color(red: 0.82, green: 0.44, blue: 0.31).opacity(0.20)
        }
    }

    /// Cita — rosado suave.
    static func highlightQuote(for theme: AppTheme) -> Color {
        switch theme {
        case .light: Color(red: 0.80, green: 0.42, blue: 0.55).opacity(0.20)
        case .dark: Color(red: 0.88, green: 0.50, blue: 0.62).opacity(0.25)
        case .sepia: Color(red: 0.75, green: 0.40, blue: 0.50).opacity(0.20)
        }
    }

    // MARK: - Colores de destacado (Highlight categories)
    
    /// Diccionario — turquesa/teal.
    static func highlightDictionary(for theme: AppTheme) -> Color {
        switch theme {
        case .light: Color(red: 0.18, green: 0.60, blue: 0.60).opacity(0.20)
        case .dark: Color(red: 0.28, green: 0.70, blue: 0.70).opacity(0.25)
        case .sepia: Color(red: 0.20, green: 0.55, blue: 0.55).opacity(0.20)
        }
    }

    /// Traducción — azul índigo.
    static func highlightTranslation(for theme: AppTheme) -> Color {
        switch theme {
        case .light: Color(red: 0.36, green: 0.36, blue: 0.75).opacity(0.20)
        case .dark: Color(red: 0.46, green: 0.46, blue: 0.85).opacity(0.25)
        case .sepia: Color(red: 0.38, green: 0.38, blue: 0.68).opacity(0.20)
        }
    }

    /// IA — celeste brillante.
    static func highlightAI(for theme: AppTheme) -> Color {
        switch theme {
        case .light: Color(red: 0.12, green: 0.53, blue: 0.82).opacity(0.20)
        case .dark: Color(red: 0.22, green: 0.63, blue: 0.92).opacity(0.25)
        case .sepia: Color(red: 0.15, green: 0.48, blue: 0.75).opacity(0.20)
        }
    }

    // MARK: - Tab bar

    /// Color de ítem activo en el tab bar.
    static func tabActive(for theme: AppTheme) -> Color {
        accent(for: theme)
    }

    /// Color de ítem inactivo en el tab bar.
    static func tabInactive(for theme: AppTheme) -> Color {
        textTertiary(for: theme)
    }
}
