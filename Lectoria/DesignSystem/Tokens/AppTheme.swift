import SwiftUI

// MARK: - AppTheme

/// Temas visuales de Lectoria.
///
/// A diferencia del `ColorScheme` del sistema que solo distingue
/// claro y oscuro, Lectoria ofrece un tercer tema sepia orientado
/// a lectura prolongada. El tema activo se almacena en `@AppStorage`
/// y es accesible a través de `ThemeManager`.
enum AppTheme: String, CaseIterable, Identifiable, Codable, Sendable {
    case light
    case dark
    case sepia

    var id: String { rawValue }

    /// Nombre localizado para la interfaz.
    var displayName: String {
        switch self {
        case .light: String(localized: "Claro", comment: "Theme name: light")
        case .dark: String(localized: "Oscuro", comment: "Theme name: dark")
        case .sepia: String(localized: "Sepia", comment: "Theme name: sepia")
        }
    }

    /// Icono SF Symbol representativo.
    var systemImage: String {
        switch self {
        case .light: "sun.max"
        case .dark: "moon"
        case .sepia: "book"
        }
    }

    /// ColorScheme del sistema asociado (sepia usa light como base).
    var colorScheme: ColorScheme {
        switch self {
        case .light, .sepia: .light
        case .dark: .dark
        }
    }
}

// MARK: - ThemeManager

/// Gestiona el tema activo de la aplicación.
///
/// Publica cambios de tema para que las vistas se actualicen
/// automáticamente. Persistido mediante `@AppStorage`.
@Observable
@MainActor
final class ThemeManager {
    /// Clave de almacenamiento para el tema seleccionado.
    private static let storageKey = "selectedTheme"

    /// Tema actualmente seleccionado.
    var currentTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: Self.storageKey)
        }
    }

    init() {
        if let stored = UserDefaults.standard.string(forKey: Self.storageKey),
           let theme = AppTheme(rawValue: stored) {
            self.currentTheme = theme
        } else {
            self.currentTheme = .light
        }
    }

    /// Alterna entre los temas disponibles en orden.
    func cycleTheme() {
        let themes = AppTheme.allCases
        guard let currentIndex = themes.firstIndex(of: currentTheme) else { return }
        let nextIndex = (currentIndex + 1) % themes.count
        currentTheme = themes[nextIndex]
    }
}
