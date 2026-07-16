import SwiftUI

// MARK: - OnboardingPage

/// Datos de cada paso del onboarding.
struct OnboardingPage: Identifiable, Sendable {
    let id: Int
    let icon: String
    let title: String
    let subtitle: String

    static let pages: [OnboardingPage] = [
        OnboardingPage(
            id: 0,
            icon: "book.pages",
            title: String(localized: "Bienvenido a Lectoria",
                          comment: "Onboarding page 1 title"),
            subtitle: String(localized: "Tu biblioteca personal para estudiar, investigar y trabajar con tus documentos.",
                             comment: "Onboarding page 1 subtitle")
        ),
        OnboardingPage(
            id: 1,
            icon: "doc.on.doc",
            title: String(localized: "Todos tus formatos",
                          comment: "Onboarding page 2 title"),
            subtitle: String(localized: "Importa EPUB, PDF, texto y Markdown. Lee todo en un solo lugar, sin complicaciones.",
                             comment: "Onboarding page 2 subtitle")
        ),
        OnboardingPage(
            id: 2,
            icon: "lock.shield",
            title: String(localized: "Privacidad primero",
                          comment: "Onboarding page 3 title"),
            subtitle: String(localized: "Tus documentos se guardan en tu dispositivo. La inteligencia artificial es opcional y siempre con tu permiso.",
                             comment: "Onboarding page 3 subtitle")
        ),
        OnboardingPage(
            id: 3,
            icon: "paintbrush",
            title: String(localized: "Tu experiencia",
                          comment: "Onboarding page 4 title"),
            subtitle: String(localized: "Elige cómo leer. Personaliza la tipografía, los colores y el tema según tu preferencia.",
                             comment: "Onboarding page 4 subtitle")
        ),
    ]
}

// MARK: - OnboardingPageView

/// Vista individual de un paso del onboarding.
struct OnboardingPageView: View {
    let page: OnboardingPage

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        let theme = themeManager.currentTheme

        VStack(spacing: AppSpacing.xl) {
            Spacer()

            Image(systemName: page.icon)
                .font(.system(size: 64))
                .foregroundStyle(AppColor.accent(for: theme))
                .symbolEffect(.pulse, options: .repeating.speed(0.5))
                .padding(.bottom, AppSpacing.lg)

            VStack(spacing: AppSpacing.md) {
                Text(page.title)
                    .font(AppTypography.largeTitle)
                    .foregroundStyle(AppColor.textPrimary(for: theme))
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColor.textSecondary(for: theme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xxl)
            }

            Spacer()
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}
