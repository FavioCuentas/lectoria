import SwiftUI

// MARK: - RootView

/// Vista raíz de la aplicación con TabView de 4 tabs.
///
/// Controla la navegación principal entre Inicio, Biblioteca,
/// Notas y Perfil. Incluye un botón de importar accesible
/// sin romper las convenciones de iOS.
struct RootView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        let theme = themeManager.currentTheme

        TabView(selection: $router.selectedTab) {
            Tab(AppTab.home.title, systemImage: AppTab.home.systemImage, value: .home) {
                NavigationStack {
                    HomeView()
                }
            }

            Tab(AppTab.library.title, systemImage: AppTab.library.systemImage, value: .library) {
                NavigationStack {
                    LibraryView()
                }
            }

            Tab(AppTab.notes.title, systemImage: AppTab.notes.systemImage, value: .notes) {
                NavigationStack {
                    NotesView()
                }
            }

            Tab(AppTab.profile.title, systemImage: AppTab.profile.systemImage, value: .profile) {
                NavigationStack {
                    ProfileView()
                }
            }
        }
        .tint(AppColor.accent(for: theme))
        .preferredColorScheme(theme.colorScheme)
    }
}

// MARK: - Preview

#Preview("Root View") {
    let themeManager = ThemeManager()
    let router = AppRouter()
    RootView()
        .environment(themeManager)
        .environment(router)
}
