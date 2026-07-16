import SwiftUI

// MARK: - ProfileView

/// Pantalla de perfil y ajustes.
///
/// Muestra opciones de cuenta, apariencia, estadísticas,
/// privacidad y soporte. En Fase 1 es funcional para tema
/// y estructura visual; otros ajustes se conectan en fases posteriores.
struct ProfileView: View {
    @Environment(ThemeManager.self) private var themeManager

    @State private var keepScreenOn = false

    var body: some View {
        let theme = themeManager.currentTheme

        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                // Sección: Cuenta
                profileSection(theme: theme) {
                    SettingsRow(
                        icon: "person.circle",
                        title: String(localized: "Cuenta", comment: "Profile: account"),
                        subtitle: String(localized: "Continuar como invitado", comment: "Profile: guest mode")
                    ) {}

                    Divider()

                    SettingsRow(
                        icon: "crown",
                        title: String(localized: "Plan", comment: "Profile: subscription plan"),
                        variant: .value(String(localized: "Gratuito", comment: "Profile: free plan"))
                    ) {}
                }

                // Sección: Apariencia
                profileSection(theme: theme) {
                    SettingsRow(
                        icon: "paintbrush",
                        title: String(localized: "Tema", comment: "Profile: theme"),
                        variant: .value(themeManager.currentTheme.displayName)
                    ) {
                        themeManager.cycleTheme()
                    }

                    Divider()

                    SettingsRow(
                        icon: "sun.max",
                        title: String(localized: "Pantalla activa al leer",
                                      comment: "Profile: keep screen on"),
                        variant: .toggle($keepScreenOn)
                    )
                }

                // Sección: Datos
                profileSection(theme: theme) {
                    SettingsRow(
                        icon: "chart.bar",
                        title: String(localized: "Estadísticas", comment: "Profile: statistics")
                    ) {}

                    Divider()

                    SettingsRow(
                        icon: "square.and.arrow.up",
                        title: String(localized: "Exportar datos", comment: "Profile: export data")
                    ) {}
                }

                // Sección: Info
                profileSection(theme: theme) {
                    SettingsRow(
                        icon: "hand.raised",
                        title: String(localized: "Política de privacidad",
                                      comment: "Profile: privacy policy")
                    ) {}

                    Divider()

                    SettingsRow(
                        icon: "doc.text",
                        title: String(localized: "Términos de uso",
                                      comment: "Profile: terms of use")
                    ) {}

                    Divider()

                    SettingsRow(
                        icon: "info.circle",
                        title: String(localized: "Acerca de Lectoria",
                                      comment: "Profile: about"),
                        subtitle: String(localized: "Versión \(AppEnvironment.current().appVersion)",
                                         comment: "Profile: version")
                    ) {}
                }

                // Zona peligrosa
                profileSection(theme: theme) {
                    SettingsRow(
                        icon: "trash",
                        title: String(localized: "Eliminar cuenta",
                                      comment: "Profile: delete account"),
                        variant: .destructive
                    ) {}
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, AppSpacing.md)
        }
        .background(AppColor.background(for: theme))
        .navigationTitle(String(localized: "Perfil", comment: "Profile screen title"))
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Section container

    private func profileSection(
        theme: AppTheme,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(.horizontal, AppSpacing.lg)
        .background(AppColor.surface(for: theme))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
    }
}

// MARK: - Preview

#Preview("Profile") {
    let themeManager = ThemeManager()
    NavigationStack {
        ProfileView()
    }
    .environment(themeManager)
}
