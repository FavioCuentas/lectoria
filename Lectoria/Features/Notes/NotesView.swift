import SwiftUI

// MARK: - NotesView

/// Pantalla de notas y destacados con estado vacío.
///
/// En Fase 1 muestra un empty state. Los datos reales
/// se conectan en Fase 6 (Anotaciones).
struct NotesView: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        let theme = themeManager.currentTheme

        EmptyStateView(
            icon: "note.text",
            title: String(localized: "Sin notas todavía",
                          comment: "Notes empty state title"),
            subtitle: String(localized: "Las notas y destacados que crees mientras lees aparecerán aquí. Podrás buscarlas, organizarlas y exportarlas.",
                             comment: "Notes empty state subtitle")
        )
        .background(AppColor.background(for: theme))
        .navigationTitle(String(localized: "Notas", comment: "Notes screen title"))
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Preview

#Preview("Notes - Empty") {
    let themeManager = ThemeManager()
    NavigationStack {
        NotesView()
    }
    .environment(themeManager)
}
