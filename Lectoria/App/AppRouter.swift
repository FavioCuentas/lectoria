import SwiftUI
import OSLog

// MARK: - AppTab

/// Tabs principales de la aplicación.
///
/// Define los 4 tabs del TabView raíz según el spec:
/// Inicio, Biblioteca, Notas, Perfil.
enum AppTab: String, CaseIterable, Identifiable, Sendable {
    case home
    case library
    case notes
    case profile

    var id: String { rawValue }

    /// Título localizado del tab.
    var title: String {
        switch self {
        case .home: String(localized: "Inicio", comment: "Tab title: Home")
        case .library: String(localized: "Biblioteca", comment: "Tab title: Library")
        case .notes: String(localized: "Notas", comment: "Tab title: Notes")
        case .profile: String(localized: "Perfil", comment: "Tab title: Profile")
        }
    }

    /// Icono SF Symbol del tab.
    var systemImage: String {
        switch self {
        case .home: "house"
        case .library: "books.vertical"
        case .notes: "note.text"
        case .profile: "person"
        }
    }

    /// Icono SF Symbol cuando el tab está seleccionado.
    var selectedSystemImage: String {
        switch self {
        case .home: "house.fill"
        case .library: "books.vertical.fill"
        case .notes: "note.text"
        case .profile: "person.fill"
        }
    }
}

// MARK: - AppRouter

/// Coordinador de navegación de la aplicación.
///
/// Gestiona el tab seleccionado y la pila de navegación
/// dentro de cada tab. Centraliza las rutas de navegación.
@Observable
@MainActor
final class AppRouter {
    /// Tab actualmente seleccionado.
    var selectedTab: AppTab = .home

    /// Publicación seleccionada para lectura.
    var selectedPublication: PublicationRecord? = nil

    /// Indica si debe mostrar el sheet de importación.
    var isShowingImport = false

    /// URL del archivo seleccionado para ser procesado por el servicio de importación.
    var pendingImportURL: URL? = nil

    /// Indica si debe mostrar el selector de creación de texto.
    var isShowingNewText = false

    /// Cambia al tab especificado.
    func navigate(to tab: AppTab) {
        selectedTab = tab
    }

    private static let logger = Logger(subsystem: "com.orvexa.Lectoria", category: "AppRouter")

    /// Abre el flujo de importación con protección contra pulsaciones repetidas.
    func showImport() {
        guard !isShowingImport else { return }
        isShowingImport = true
    }

    /// Maneja el resultado del selector de archivos (`.fileImporter`).
    func handleImportResult(_ result: Result<[URL], Error>) {
        isShowingImport = false
        switch result {
        case .success(let urls):
            if let url = urls.first {
                pendingImportURL = url
            }
        case .failure:
            Self.logger.error("Error al seleccionar archivo en el selector del sistema.")
        }
    }

    /// Abre el flujo de creación de texto pegado.
    func showNewText() {
        isShowingNewText = true
    }
}
