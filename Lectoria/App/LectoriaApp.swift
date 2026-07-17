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
            .onOpenURL { url in
                handleOpenURL(url)
            }
        }
    }

    private func handleOpenURL(_ url: URL) {
        Task {
            do {
                if url.isFileURL {
                    let record = try await dependencies.importService.importPublication(from: url)
                    router.selectedTab = .library
                    router.selectedPublication = record
                } else if url.scheme == "lectoria", url.host == "import-text" {
                    if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                       let queryItems = components.queryItems {
                        let text = queryItems.first(where: { $0.name == "text" })?.value ?? ""
                        let title = queryItems.first(where: { $0.name == "title" })?.value ?? String(localized: "Texto importado", comment: "Sync: imported text title fallback")
                        
                        if !text.isEmpty {
                            let record = try await dependencies.importService.importPastedText(text: text, title: title)
                            router.selectedTab = .library
                            router.selectedPublication = record
                        }
                    }
                }
            } catch {
                print("Error al importar desde URL externa: \(error.localizedDescription)")
            }
        }
    }
}
