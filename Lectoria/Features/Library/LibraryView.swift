import SwiftUI

// MARK: - LibraryView

/// Pantalla de biblioteca con cuadrícula/lista, filtros, búsqueda
/// y estados vacíos.
///
/// En Fase 1 muestra un empty state con el Design System.
/// Los datos reales se conectan en Fase 2 (SwiftData) y Fase 5.
struct LibraryView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppRouter.self) private var router

    @State private var searchText = ""
    @State private var isGridView = true
    @State private var selectedFilter: LibraryFilter = .all

    var body: some View {
        let theme = themeManager.currentTheme

        VStack(spacing: 0) {
            // Filtros
            filterBar(theme: theme)

            // Contenido
            if hasDocuments {
                contentView(theme: theme)
            } else {
                EmptyStateView(
                    icon: "books.vertical",
                    title: String(localized: "Tu biblioteca está vacía",
                                  comment: "Library empty state title"),
                    subtitle: String(localized: "Importa tu primer EPUB, PDF o archivo de texto para comenzar a leer.",
                                     comment: "Library empty state subtitle"),
                    actionTitle: String(localized: "Importar documento",
                                        comment: "Library empty state action")
                ) {
                    router.showImport()
                }
            }
        }
        .background(AppColor.background(for: theme))
        .navigationTitle(String(localized: "Biblioteca", comment: "Library screen title"))
        .navigationBarTitleDisplayMode(.large)
        .searchable(
            text: $searchText,
            prompt: String(localized: "Buscar por título, autor…",
                          comment: "Library search placeholder")
        )
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isGridView.toggle()
                    }
                } label: {
                    Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2")
                }
                .accessibilityLabel(
                    isGridView
                    ? String(localized: "Cambiar a vista de lista", comment: "Library toggle to list")
                    : String(localized: "Cambiar a cuadrícula", comment: "Library toggle to grid")
                )

                Button {
                    router.showImport()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(String(localized: "Importar", comment: "Library import button"))
            }
        }
    }

    // MARK: - Filter bar

    private func filterBar(theme: AppTheme) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(LibraryFilter.allCases) { filter in
                    FilterChip(
                        filter.displayName,
                        icon: filter.systemImage,
                        isSelected: selectedFilter == filter
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, AppSpacing.sm)
        }
    }

    // MARK: - Content (placeholder for Fase 5)

    @ViewBuilder
    private func contentView(theme: AppTheme) -> some View {
        // Se conectará a datos reales en Fase 5
        ScrollView {
            Text("Contenido de biblioteca")
                .foregroundStyle(AppColor.textTertiary(for: theme))
        }
    }

    // MARK: - Helpers

    /// En Fase 1 siempre es false. Se conecta a datos en Fase 2.
    private var hasDocuments: Bool { false }
}

// MARK: - LibraryFilter

/// Filtros disponibles en la biblioteca.
enum LibraryFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case epub
    case pdf
    case txt
    case markdown
    case inProgress
    case finished
    case notStarted
    case favorites

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: String(localized: "Todos", comment: "Library filter: all")
        case .epub: "EPUB"
        case .pdf: "PDF"
        case .txt: String(localized: "Texto", comment: "Library filter: text")
        case .markdown: "Markdown"
        case .inProgress: String(localized: "En progreso", comment: "Library filter: in progress")
        case .finished: String(localized: "Terminados", comment: "Library filter: finished")
        case .notStarted: String(localized: "No iniciados", comment: "Library filter: not started")
        case .favorites: String(localized: "Favoritos", comment: "Library filter: favorites")
        }
    }

    var systemImage: String? {
        switch self {
        case .all: nil
        case .epub: "book"
        case .pdf: "doc.richtext"
        case .txt: "doc.text"
        case .markdown: "text.document"
        case .inProgress: "clock"
        case .finished: "checkmark.circle"
        case .notStarted: "circle"
        case .favorites: "heart"
        }
    }
}

// MARK: - Preview

#Preview("Library - Empty") {
    let themeManager = ThemeManager()
    let router = AppRouter()
    NavigationStack {
        LibraryView()
    }
    .environment(themeManager)
    .environment(router)
}
