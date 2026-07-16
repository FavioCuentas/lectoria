import SwiftUI

// MARK: - PrimaryButton

/// Botón principal con fondo de acento y texto claro.
///
/// Usado para acciones principales: importar, guardar, continuar.
/// Soporta Dynamic Type, estado de carga y estado deshabilitado.
struct PrimaryButton: View {
    let title: String
    let icon: String?
    let isLoading: Bool
    let action: () -> Void

    @Environment(ThemeManager.self) private var themeManager

    init(
        _ title: String,
        icon: String? = nil,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if let icon {
                    Image(systemName: icon)
                        .font(AppTypography.bodyBold)
                }
                Text(title)
                    .font(AppTypography.bodyBold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .padding(.horizontal, AppSpacing.lg)
            .background(AppColor.accent(for: themeManager.currentTheme))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.8 : 1.0)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - SecondaryButton

/// Botón secundario con borde y fondo transparente.
///
/// Usado para acciones secundarias: cancelar, omitir.
struct SecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    @Environment(ThemeManager.self) private var themeManager

    init(
        _ title: String,
        icon: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        let theme = themeManager.currentTheme
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(AppTypography.body)
                }
                Text(title)
                    .font(AppTypography.body)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .padding(.horizontal, AppSpacing.lg)
            .foregroundStyle(AppColor.accent(for: theme))
            .background(AppColor.surface(for: theme))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .strokeBorder(AppColor.accent(for: theme), lineWidth: 1.5)
            )
        }
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - IconButton

/// Botón circular con icono SF Symbol.
///
/// Usado en toolbars, acciones rápidas y controles del lector.
struct IconButton: View {
    let icon: String
    let label: String
    let size: Size
    let action: () -> Void

    @Environment(ThemeManager.self) private var themeManager

    enum Size {
        case small, medium, large

        var dimension: CGFloat {
            switch self {
            case .small: 32
            case .medium: 40
            case .large: 48
            }
        }

        var iconFont: Font {
            switch self {
            case .small: .caption
            case .medium: .body
            case .large: .title3
            }
        }
    }

    init(
        icon: String,
        label: String,
        size: Size = .medium,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.label = label
        self.size = size
        self.action = action
    }

    var body: some View {
        let theme = themeManager.currentTheme
        Button(action: action) {
            Image(systemName: icon)
                .font(size.iconFont)
                .foregroundStyle(AppColor.textPrimary(for: theme))
                .frame(width: size.dimension, height: size.dimension)
                .background(AppColor.surfaceSecondary(for: theme))
                .clipShape(Circle())
        }
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Previews

#Preview("Buttons") {
    let themeManager = ThemeManager()
    VStack(spacing: AppSpacing.lg) {
        PrimaryButton("Importar documento", icon: "plus.circle.fill") {}
        PrimaryButton("Cargando...", isLoading: true) {}
        SecondaryButton("Omitir", icon: "arrow.right") {}
        HStack(spacing: AppSpacing.md) {
            IconButton(icon: "bookmark", label: "Marcador") {}
            IconButton(icon: "magnifyingglass", label: "Buscar") {}
            IconButton(icon: "textformat.size", label: "Apariencia", size: .large) {}
            IconButton(icon: "ellipsis", label: "Más", size: .small) {}
        }
    }
    .padding()
    .background(AppColor.background(for: themeManager.currentTheme))
    .environment(themeManager)
}
