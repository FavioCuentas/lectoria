import SwiftUI

// MARK: - PrivacySettingsView

/// Perfil → Privacidad: qué datos salen del iPhone y el interruptor de la analítica anónima.
struct PrivacySettingsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Bindable private var analytics = AnalyticsPrivacyManager.shared

    var body: some View {
        let theme = themeManager.currentTheme

        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(spacing: 0) {
                    SettingsRow(
                        icon: "chart.bar.xaxis",
                        title: String(localized: "Compartir analítica anónima", comment: "Privacy: anonymous analytics toggle"),
                        variant: .toggle($analytics.isAnalyticsEnabled)
                    )
                }
                .padding(.horizontal, AppSpacing.lg)
                .background(AppColor.surface(for: theme))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))

                explanation(
                    String(localized: "Nos ayuda a saber qué funciones se usan y dónde falla la app, por ejemplo cuándo se abre o se importa un documento. Va con un identificador anónimo de esta instalación y nunca incluye el contenido de tus documentos, notas ni búsquedas.",
                           comment: "Privacy: analytics explanation"),
                    theme: theme
                )

                Text(String(localized: "Lo que se queda en tu iPhone", comment: "Privacy: on-device section title"))
                    .font(AppTypography.title)
                    .foregroundStyle(AppColor.textPrimary(for: theme))
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, AppSpacing.sm)

                explanation(
                    String(localized: "Tus documentos no salen del teléfono. La búsqueda, las estadísticas y las funciones de IA del lector se calculan en el dispositivo. Si inicias sesión, se guarda una copia de seguridad de tus marcadores, destacados, notas y progreso.",
                           comment: "Privacy: on-device explanation"),
                    theme: theme
                )
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, AppSpacing.md)
        }
        .background(AppColor.background(for: theme))
        .navigationTitle(String(localized: "Privacidad", comment: "Privacy screen title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func explanation(_ text: String, theme: AppTheme) -> some View {
        Text(text)
            .font(AppTypography.callout)
            .foregroundStyle(AppColor.textSecondary(for: theme))
            .fixedSize(horizontal: false, vertical: true)
    }
}
