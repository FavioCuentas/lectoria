import SwiftUI

// MARK: - OnboardingView

/// Flujo de onboarding con 4 pasos, indicador de progreso y
/// botones de continuar/omitir.
///
/// Principios del spec:
/// - Máximo 4 a 6 pasos.
/// - Permitir omitir.
/// - No obligar a pagar.
/// - No pedir permisos sin contexto.
struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var currentPage = 0
    @Environment(ThemeManager.self) private var themeManager

    private let pages = OnboardingPage.pages

    var body: some View {
        let theme = themeManager.currentTheme
        let isLastPage = currentPage == pages.count - 1

        VStack(spacing: 0) {
            // Skip button
            HStack {
                Spacer()
                Button {
                    onComplete()
                } label: {
                    Text(String(localized: "Omitir", comment: "Onboarding skip button"))
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColor.textSecondary(for: theme))
                }
                .padding(.trailing, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.md)
                .opacity(isLastPage ? 0 : 1)
            }

            // Pages
            TabView(selection: $currentPage) {
                ForEach(pages) { page in
                    OnboardingPageView(page: page)
                        .tag(page.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentPage)

            // Progress indicators
            HStack(spacing: AppSpacing.sm) {
                ForEach(pages) { page in
                    Capsule()
                        .fill(page.id == currentPage
                              ? AppColor.accent(for: theme)
                              : AppColor.border(for: theme))
                        .frame(width: page.id == currentPage ? 24 : 8, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: currentPage)
                }
            }
            .padding(.bottom, AppSpacing.xl)

            // Theme selector on last page
            if isLastPage {
                themeSelector
                    .padding(.bottom, AppSpacing.lg)
                    .transition(.opacity)
            }

            // Action button
            PrimaryButton(
                isLastPage
                ? String(localized: "Comenzar", comment: "Onboarding start button")
                : String(localized: "Continuar", comment: "Onboarding continue button"),
                icon: isLastPage ? "arrow.right.circle.fill" : nil
            ) {
                if isLastPage {
                    onComplete()
                } else {
                    withAnimation {
                        currentPage += 1
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.bottom, AppSpacing.xxxl)
        }
        .background(AppColor.background(for: theme))
        .preferredColorScheme(theme.colorScheme)
    }

    // MARK: - Theme selector

    private var themeSelector: some View {
        let theme = themeManager.currentTheme

        return VStack(spacing: AppSpacing.md) {
            Text(String(localized: "Elige tu tema", comment: "Onboarding theme selector title"))
                .font(AppTypography.subtitle)
                .foregroundStyle(AppColor.textSecondary(for: theme))

            HStack(spacing: AppSpacing.lg) {
                ForEach(AppTheme.allCases) { appTheme in
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            themeManager.currentTheme = appTheme
                        }
                    } label: {
                        VStack(spacing: AppSpacing.sm) {
                            Circle()
                                .fill(AppColor.background(for: appTheme))
                                .frame(width: 48, height: 48)
                                .overlay(
                                    Circle()
                                        .strokeBorder(
                                            appTheme == theme
                                            ? AppColor.accent(for: theme)
                                            : AppColor.border(for: theme),
                                            lineWidth: appTheme == theme ? 2.5 : 1
                                        )
                                )

                            Text(appTheme.displayName)
                                .font(AppTypography.caption)
                                .foregroundStyle(
                                    appTheme == theme
                                    ? AppColor.accent(for: theme)
                                    : AppColor.textSecondary(for: theme)
                                )
                        }
                    }
                    .accessibilityLabel(appTheme.displayName)
                    .accessibilityAddTraits(appTheme == theme ? [.isSelected] : [])
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Onboarding") {
    let themeManager = ThemeManager()
    OnboardingView {}
        .environment(themeManager)
}
