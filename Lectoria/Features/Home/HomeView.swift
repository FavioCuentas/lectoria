import SwiftUI

// MARK: - HomeView

/// Pantalla de inicio minimalista.
///
/// Diseño limpio inspirado en Kindle: saludo simple,
/// tarjeta de continuar leyendo, acciones discretas.
struct HomeView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppRouter.self) private var router

    var body: some View {
        let theme = themeManager.currentTheme

        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.xxl) {
                // Saludo
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(contextualGreeting)
                        .font(AppTypography.largeTitle)
                        .foregroundStyle(AppColor.textPrimary(for: theme))

                    Text(String(localized: "¿Qué vas a leer hoy?",
                                comment: "Home screen subtitle"))
                        .font(AppTypography.body)
                        .foregroundStyle(AppColor.textTertiary(for: theme))
                }

                // Continuar leyendo
                continueReadingSection(theme: theme)

                // Acciones rápidas
                quickActionsSection(theme: theme)

                // Recientes
                recentSection(theme: theme)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxxl)
        }
        .background(AppColor.background(for: theme))
        .navigationTitle(String(localized: "Inicio", comment: "Home screen title"))
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Continue Reading

    private func continueReadingSection(theme: AppTheme) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(String(localized: "Continuar leyendo",
                        comment: "Home section: continue reading"))
                .font(AppTypography.callout)
                .foregroundStyle(AppColor.textSecondary(for: theme))

            // Empty state — minimal
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "book.closed")
                    .font(.title3)
                    .foregroundStyle(AppColor.textTertiary(for: theme))

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(String(localized: "Sin lecturas en progreso",
                                comment: "Home: no reading"))
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColor.textSecondary(for: theme))

                    Text(String(localized: "Importa un documento para comenzar",
                                comment: "Home: import hint"))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColor.textTertiary(for: theme))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.lg)
            .background(AppColor.surface(for: theme))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        }
    }

    // MARK: - Quick Actions

    private func quickActionsSection(theme: AppTheme) -> some View {
        HStack(spacing: AppSpacing.md) {
            Button {
                router.showImport()
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "plus")
                        .font(AppTypography.body)
                    Text(String(localized: "Importar", comment: "Home: import"))
                        .font(AppTypography.callout)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(AppColor.accent(for: theme))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            }

            Button {
                router.showNewText()
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "doc.on.clipboard")
                        .font(AppTypography.body)
                    Text(String(localized: "Pegar texto", comment: "Home: paste text"))
                        .font(AppTypography.callout)
                }
                .foregroundStyle(AppColor.textPrimary(for: theme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(AppColor.surface(for: theme))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .strokeBorder(AppColor.border(for: theme), lineWidth: 1)
                )
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recent

    private func recentSection(theme: AppTheme) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text(String(localized: "Recientes", comment: "Home section: recent"))
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColor.textSecondary(for: theme))
                Spacer()
                Button {
                    router.navigate(to: .library)
                } label: {
                    Text(String(localized: "Ver todo", comment: "Home: see all"))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColor.accent(for: theme))
                }
            }

            Text(String(localized: "Aún no hay documentos",
                        comment: "Home: empty recent"))
                .font(AppTypography.footnote)
                .foregroundStyle(AppColor.textTertiary(for: theme))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, AppSpacing.lg)
        }
    }

    // MARK: - Helpers

    private var contextualGreeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12:
            return String(localized: "Buenos días", comment: "Greeting: morning")
        case 12..<18:
            return String(localized: "Buenas tardes", comment: "Greeting: afternoon")
        default:
            return String(localized: "Buenas noches", comment: "Greeting: evening")
        }
    }
}

// MARK: - Preview

#Preview("Home") {
    let themeManager = ThemeManager()
    let router = AppRouter()
    NavigationStack {
        HomeView()
    }
    .environment(themeManager)
    .environment(router)
}
