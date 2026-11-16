import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.orvexa.Lectoria", category: "App")

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

    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
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
                
                if showSplash {
                    SplashScreenView()
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
            }
            .environment(themeManager)
            .environment(router)
            .environment(dependencies)
            .modelContainer(modelContainer)
            .onOpenURL { url in
                handleOpenURL(url)
            }
            .task {
                try? await Task.sleep(for: .seconds(1.8))
                withAnimation(.easeOut(duration: 0.4)) {
                    showSplash = false
                }
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
                logger.error("Error al importar desde URL externa: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - SplashScreenView

struct SplashScreenView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            if colorScheme == .dark {
                Color(red: 0.10, green: 0.10, blue: 0.12)
                    .ignoresSafeArea()
            } else {
                Color(red: 0.98, green: 0.98, blue: 0.97)
                    .ignoresSafeArea()
            }
            
            VStack(spacing: AppSpacing.md) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 32))
                    .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
                
                Text("Lectoria")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(colorScheme == .dark ? .white : Color(red: 0.15, green: 0.15, blue: 0.20))
            }
        }
    }
}
