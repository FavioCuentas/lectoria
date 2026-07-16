import SwiftUI

// MARK: - LectoriaApp

/// Punto de entrada de la aplicación.
///
/// Controla el flujo inicial:
/// - Si el usuario no ha completado el onboarding, muestra `OnboardingView`.
/// - Si ya lo completó, muestra `RootView` con los 4 tabs.
///
/// Inyecta `ThemeManager` y `AppRouter` en el environment.
@main
struct LectoriaApp: App {
    @State private var themeManager = ThemeManager()
    @State private var router = AppRouter()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    RootView()
                } else {
                    OnboardingView {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            hasCompletedOnboarding = true
                        }
                    }
                }
            }
            .environment(themeManager)
            .environment(router)
        }
    }
}
