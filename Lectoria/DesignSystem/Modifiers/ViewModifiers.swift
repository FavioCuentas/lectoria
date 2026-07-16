import SwiftUI

// MARK: - View Modifiers

/// Aplica el fondo principal del tema actual a la vista.
struct ThemedBackgroundModifier: ViewModifier {
    @Environment(ThemeManager.self) private var themeManager

    func body(content: Content) -> some View {
        content
            .background(AppColor.background(for: themeManager.currentTheme))
    }
}

/// Aplica sombra sutil del tema actual.
struct SubtleShadowModifier: ViewModifier {
    @Environment(ThemeManager.self) private var themeManager

    func body(content: Content) -> some View {
        let shadow = AppShadow.subtle(for: themeManager.currentTheme)
        content
            .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

/// Aplica estilo de card con superficie, borde y sombra.
struct CardModifier: ViewModifier {
    @Environment(ThemeManager.self) private var themeManager

    func body(content: Content) -> some View {
        let theme = themeManager.currentTheme
        let shadow = AppShadow.subtle(for: theme)
        content
            .padding(AppSpacing.lg)
            .background(AppColor.surface(for: theme))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .strokeBorder(AppColor.border(for: theme), lineWidth: 0.5)
            )
            .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

/// Aplica estilo de sección con título.
struct SectionHeaderModifier: ViewModifier {
    @Environment(ThemeManager.self) private var themeManager

    func body(content: Content) -> some View {
        content
            .font(AppTypography.subtitle)
            .foregroundStyle(AppColor.textSecondary(for: themeManager.currentTheme))
            .textCase(.uppercase)
            .tracking(0.5)
    }
}

// MARK: - View Extensions

extension View {
    /// Aplica el fondo del tema actual.
    func themedBackground() -> some View {
        modifier(ThemedBackgroundModifier())
    }

    /// Aplica sombra sutil adaptada al tema.
    func subtleShadow() -> some View {
        modifier(SubtleShadowModifier())
    }

    /// Aplica estilo de card con superficie y sombra.
    func cardStyle() -> some View {
        modifier(CardModifier())
    }

    /// Aplica estilo de encabezado de sección.
    func sectionHeader() -> some View {
        modifier(SectionHeaderModifier())
    }
}
