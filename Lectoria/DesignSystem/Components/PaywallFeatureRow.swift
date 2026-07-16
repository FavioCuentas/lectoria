import SwiftUI

// MARK: - PaywallFeatureRow

/// Fila que muestra una característica del plan Premium en el paywall.
///
/// Incluye un icono de check, nombre de la feature y descripción.
/// No muestra precios; esos provienen de StoreKit.
struct PaywallFeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        let theme = themeManager.currentTheme

        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(AppTypography.body)
                .foregroundStyle(AppColor.accent(for: theme))
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .font(AppTypography.bodyBold)
                    .foregroundStyle(AppColor.textPrimary(for: theme))

                Text(subtitle)
                    .font(AppTypography.footnote)
                    .foregroundStyle(AppColor.textSecondary(for: theme))
            }

            Spacer()
        }
        .padding(.vertical, AppSpacing.sm)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - ReaderToolbar

/// Barra de herramientas del lector (placeholder para Fase 3+).
///
/// Muestra los controles inferiores del lector: capítulo, búsqueda,
/// apariencia, notas e índice.
struct ReaderToolbar: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        let theme = themeManager.currentTheme

        HStack(spacing: AppSpacing.xxl) {
            toolbarItem(icon: "list.bullet", label: String(localized: "Índice", comment: "Reader toolbar: TOC"))
            toolbarItem(icon: "magnifyingglass", label: String(localized: "Buscar", comment: "Reader toolbar: Search"))
            toolbarItem(icon: "textformat.size", label: String(localized: "Apariencia", comment: "Reader toolbar: Appearance"))
            toolbarItem(icon: "note.text", label: String(localized: "Notas", comment: "Reader toolbar: Notes"))
        }
        .padding(.vertical, AppSpacing.md)
        .padding(.horizontal, AppSpacing.lg)
        .background(AppColor.surface(for: theme))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .shadow(
            color: AppShadow.medium(for: theme).color,
            radius: AppShadow.medium(for: theme).radius,
            x: AppShadow.medium(for: theme).x,
            y: AppShadow.medium(for: theme).y
        )
    }

    private func toolbarItem(icon: String, label: String) -> some View {
        let theme = themeManager.currentTheme
        return Button {} label: {
            VStack(spacing: AppSpacing.xxs) {
                Image(systemName: icon)
                    .font(AppTypography.body)
                Text(label)
                    .font(AppTypography.caption)
            }
            .foregroundStyle(AppColor.textSecondary(for: theme))
        }
        .accessibilityLabel(label)
    }
}

// MARK: - Preview

#Preview("Paywall & Reader") {
    let themeManager = ThemeManager()
    VStack(spacing: AppSpacing.xl) {
        VStack(spacing: AppSpacing.sm) {
            PaywallFeatureRow(
                icon: "infinity",
                title: "Documentos ilimitados",
                subtitle: "Sin límite de archivos en tu biblioteca"
            )
            PaywallFeatureRow(
                icon: "brain",
                title: "IA con cuota mensual",
                subtitle: "Explicaciones, resúmenes y preguntas de estudio"
            )
            PaywallFeatureRow(
                icon: "arrow.triangle.2.circlepath",
                title: "Sincronización",
                subtitle: "Accede a tus documentos desde cualquier dispositivo"
            )
        }
        .padding()
        .background(AppColor.surface(for: themeManager.currentTheme))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))

        Spacer()

        ReaderToolbar()
    }
    .padding()
    .background(AppColor.background(for: themeManager.currentTheme))
    .environment(themeManager)
}
