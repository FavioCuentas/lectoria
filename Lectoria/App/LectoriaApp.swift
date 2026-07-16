import SwiftUI
import SwiftData

// MARK: - LectoriaApp

/// Punto de entrada de la aplicación.
///
/// Controla el flujo inicial:
/// - Si el usuario no ha completado el onboarding, muestra `OnboardingView`.
/// - Si ya lo completó, muestra `RootView` con los 4 tabs.
///
/// Inyecta `ThemeManager`, `AppRouter`, `modelContainer` y `AppDependencies` en el environment.
@main
struct LectoriaApp: App {
    @State private var themeManager = ThemeManager()
    @State private var router = AppRouter()
    @State private var dependencies: AppDependencies
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    private let modelContainer: ModelContainer

    init() {
        // Inicializar el contenedor de SwiftData (producción en disco)
        let container = ModelContainerFactory.create(isStoredInMemoryOnly: false)
        self.modelContainer = container
        
        // Inicializar el contenedor de dependencias del negocio
        self._dependencies = State(initialValue: AppDependencies(modelContainer: container))
    }

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
            .environment(dependencies)
            .modelContainer(modelContainer)
        }
    }
}
