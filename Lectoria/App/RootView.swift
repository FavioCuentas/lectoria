import SwiftUI
import UniformTypeIdentifiers

// MARK: - RootView

/// Vista raíz de la aplicación con TabView de 4 tabs.
///
/// Controla la navegación principal entre Inicio, Biblioteca,
/// Notas y Perfil. Incluye un botón de importar accesible
/// sin romper las convenciones de iOS.
struct RootView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppRouter.self) private var router
    @Environment(AppDependencies.self) private var dependencies

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
        .fileImporter(
            isPresented: $router.isShowingImport,
            allowedContentTypes: [
                .pdf,
                UTType(filenameExtension: "epub") ?? .data,
                .plainText,
                UTType(filenameExtension: "md") ?? .plainText
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importFile(at: url)
                }
            case .failure(let error):
                print("Error al seleccionar archivo: \(error.localizedDescription)")
            }
        }
        .sheet(isPresented: $router.isShowingNewText) {
            NewTextView()
        }
    }

    private func importFile(at url: URL) {
        Task {
            do {
                let record = try await dependencies.importService.importPublication(from: url)
                // Redirigir al lector correspondiente
                router.selectedPublication = record
            } catch {
                print("Error al importar publicación: \(error.localizedDescription)")
            }
        }
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
