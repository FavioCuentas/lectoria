import SwiftUI
import SwiftData

// MARK: - LibraryView

/// Pantalla de biblioteca con cuadrícula/lista, filtros, búsqueda
/// y estados vacíos conectados a base de datos.
struct LibraryView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \PublicationModel.createdAt, order: .reverse) private var publicationModels: [PublicationModel]

    @State private var searchText = ""
    @State private var isGridView = true
    @State private var selectedFilter: LibraryFilter = .all

    var body: some View {
        @Bindable var router = router
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
        .navigationDestination(item: $router.selectedPublication) { record in
            switch record.publicationType {
            case .pdf:
                PDFReaderView(record: record)
            case .epub:
                EPUBReaderView(record: record)
            case .txt, .markdown, .pastedText:
                TextReaderView(record: record)
            }
        }
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

    // MARK: - Content

    @ViewBuilder
    private func contentView(theme: AppTheme) -> some View {
        let items = filteredModels
        
        if items.isEmpty {
            VStack(spacing: AppSpacing.md) {
                Spacer()
                Image(systemName: "magnifyingglass")
                    .font(.largeTitle)
                    .foregroundStyle(AppColor.textTertiary(for: theme))
                Text("No hay resultados")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColor.textSecondary(for: theme))
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                if isGridView {
                    let columns = [
                        GridItem(.flexible(), spacing: AppSpacing.lg),
                        GridItem(.flexible(), spacing: AppSpacing.lg)
                    ]
                    
                    LazyVGrid(columns: columns, spacing: AppSpacing.xl) {
                        ForEach(items) { model in
                            let record = model.toDomain()
                            let progress = model.progressList.max(by: { $0.updatedAt < $1.updatedAt })?.percentage ?? 0.0
                            
                            PublicationCard(
                                publication: record,
                                style: .grid,
                                progress: progress
                            ) {
                                router.selectedPublication = record
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.vertical, AppSpacing.md)
                } else {
                    LazyVStack(spacing: AppSpacing.md) {
                        ForEach(items) { model in
                            let record = model.toDomain()
                            let progress = model.progressList.max(by: { $0.updatedAt < $1.updatedAt })?.percentage ?? 0.0
                            
                            PublicationCard(
                                publication: record,
                                style: .list,
                                progress: progress
                            ) {
                                router.selectedPublication = record
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.vertical, AppSpacing.md)
                }
            }
        }
    }

    // MARK: - Helpers

    private var hasDocuments: Bool {
        !publicationModels.isEmpty
    }

    private var filteredModels: [PublicationModel] {
        publicationModels.filter { model in
            let record = model.toDomain()
            
            // Filtro de búsqueda por texto
            if !searchText.isEmpty {
                let matchesSearch = record.title.localizedCaseInsensitiveContains(searchText) ||
                    (record.author?.localizedCaseInsensitiveContains(searchText) ?? false)
                guard matchesSearch else { return false }
            }
            
            // Filtro por tipo o estado
            switch selectedFilter {
            case .all:
                return true
            case .epub:
                return record.publicationType == .epub
            case .pdf:
                return record.publicationType == .pdf
            case .txt:
                return record.publicationType == .txt
            case .markdown:
                return record.publicationType == .markdown
            case .inProgress:
                let progress = model.progressList.max(by: { $0.updatedAt < $1.updatedAt })?.percentage ?? 0.0
                return progress > 0.0 && progress < 1.0
            case .finished:
                return record.finishedAt != nil
            case .notStarted:
                return model.progressList.isEmpty
            case .favorites:
                return record.isFavorite
            }
        }
    }
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
