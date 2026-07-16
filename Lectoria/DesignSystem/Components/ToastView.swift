import SwiftUI

// MARK: - ToastView

/// Notificación temporal que aparece brevemente y desaparece.
///
/// Usada para confirmar acciones: "Marcador añadido", "Nota guardada".
/// No bloquea la interacción. Se muestra sobre el contenido.
struct ToastView: View {
    let message: String
    let icon: String
    let style: Style

    @Environment(ThemeManager.self) private var themeManager

    enum Style {
        case success
        case error
        case info

        func color(for theme: AppTheme) -> Color {
            switch self {
            case .success: AppColor.success(for: theme)
            case .error: AppColor.error(for: theme)
            case .info: AppColor.accent(for: theme)
            }
        }
    }

    init(_ message: String, icon: String = "checkmark.circle.fill", style: Style = .success) {
        self.message = message
        self.icon = icon
        self.style = style
    }

    var body: some View {
        let theme = themeManager.currentTheme

        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(style.color(for: theme))

            Text(message)
                .font(AppTypography.callout)
                .foregroundStyle(AppColor.textPrimary(for: theme))
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .background(AppColor.surface(for: theme))
        .clipShape(Capsule())
        .shadow(
            color: AppShadow.prominent(for: theme).color,
            radius: AppShadow.prominent(for: theme).radius,
            x: AppShadow.prominent(for: theme).x,
            y: AppShadow.prominent(for: theme).y
        )
        .accessibilityLabel(message)
        .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - LoadingStateView

/// Estado de carga con indicador y mensaje opcional.
struct LoadingStateView: View {
    let message: String?

    @Environment(ThemeManager.self) private var themeManager

    init(_ message: String? = nil) {
        self.message = message
    }

    var body: some View {
        let theme = themeManager.currentTheme

        VStack(spacing: AppSpacing.lg) {
            Spacer()

            ProgressView()
                .controlSize(.large)
                .tint(AppColor.accent(for: theme))

            if let message {
                Text(message)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColor.textSecondary(for: theme))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(message ?? String(localized: "Cargando", comment: "Loading state"))
    }
}

// MARK: - ErrorStateView

/// Estado de error con icono, mensaje y acción de reintento.
struct ErrorStateView: View {
    let error: AppError
    let retryAction: (() -> Void)?

    @Environment(ThemeManager.self) private var themeManager

    init(_ error: AppError, retryAction: (() -> Void)? = nil) {
        self.error = error
        self.retryAction = retryAction
    }

    var body: some View {
        let theme = themeManager.currentTheme

        VStack(spacing: AppSpacing.lg) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundStyle(AppColor.error(for: theme))

            VStack(spacing: AppSpacing.sm) {
                Text(error.alertTitle)
                    .font(AppTypography.title2)
                    .foregroundStyle(AppColor.textPrimary(for: theme))

                Text(error.errorDescription ?? "")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColor.textSecondary(for: theme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xxl)
            }

            if let retryAction {
                SecondaryButton(
                    String(localized: "Reintentar", comment: "Error state retry button"),
                    icon: "arrow.clockwise"
                ) {
                    retryAction()
                }
                .padding(.horizontal, AppSpacing.huge)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Previews

#Preview("Toasts") {
    let themeManager = ThemeManager()
    VStack(spacing: AppSpacing.lg) {
        ToastView("Marcador añadido")
        ToastView("Error al guardar", icon: "xmark.circle.fill", style: .error)
        ToastView("Documento importado", icon: "doc.badge.plus", style: .info)
    }
    .padding()
    .background(AppColor.background(for: themeManager.currentTheme))
    .environment(themeManager)
}

#Preview("Loading State") {
    let themeManager = ThemeManager()
    LoadingStateView("Importando documento…")
        .background(AppColor.background(for: themeManager.currentTheme))
        .environment(themeManager)
}

#Preview("Error State") {
    let themeManager = ThemeManager()
    ErrorStateView(.corruptedFile(fileName: "libro.epub")) {}
        .background(AppColor.background(for: themeManager.currentTheme))
        .environment(themeManager)
}
