import SwiftUI
import SwiftData

// MARK: - LibraryView

/// Pantalla de biblioteca con cuadrícula/lista, filtros, búsqueda,
/// selección de 5 documentos activos para plan Free y estados vacíos.
struct LibraryView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppRouter.self) private var router
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \PublicationModel.createdAt, order: .reverse) private var publicationModels: [PublicationModel]

    @State private var searchText = ""
    @State private var isGridView = true
    @State private var selectedFilter: LibraryFilter = .all
    @State private var showActiveSelector = false
    @State private var showArchivedAlert = false
    @State private var showPaywall = false
    @State private var selectedArchivedRecord: PublicationRecord?

    var body: some View {
        @Bindable var router = router
        let theme = themeManager.currentTheme

        VStack(spacing: 0) {
            // Banner de estado Free (si hay más de 5 documentos o archivados)
            if shouldShowFreeBanner {
                freeActiveLimitBanner(theme: theme)
            }

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
            case .txt, .markdown, .pastedText, .pptx:
                TextReaderView(record: record)
            }
        }
        .sheet(isPresented: $showActiveSelector) {
            ActiveDocumentSelectorView(publications: publicationModels.map { $0.toDomain() }) {}
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .alert(
            String(localized: "Documento Archivado", comment: "Alert title: archived document"),
            isPresented: $showArchivedAlert
        ) {
            Button(String(localized: "Cambiar 5 activos", comment: "Alert button: selector")) {
                showActiveSelector = true
            }
            Button(String(localized: "Ver planes Premium", comment: "Alert button: paywall")) {
                showPaywall = true
            }
            Button(String(localized: "Cancelar", comment: "Cancel"), role: .cancel) {}
        } message: {
            if let record = selectedArchivedRecord {
                Text(String(localized: "'\(record.title)' está archivado porque el plan Free permite máximo 5 documentos activos. Puedes activarlo reemplazando uno de tus 5 activos o suscribirte a Premium.", comment: "Archived alert message"))
            }
        }
        .onAppear {
            dependencies.analyticsService.track(.libraryViewed, properties: [
                "total_documents_count": publicationModels.count,
                "favorite_count": publicationModels.filter { $0.isFavorite }.count
            ])
            checkFreePlanActiveCount()
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
        .task {
            await dependencies.seedSamplePresentationIfNeeded()
        }
    }

    // MARK: - Free Plan Limit Banner

    private var shouldShowFreeBanner: Bool {
        let isFree = !dependencies.subscriptionService.hasActiveSubscription
        let activeCount = publicationModels.filter { !$0.isArchived }.count
        let archivedCount = publicationModels.filter { $0.isArchived }.count
        return isFree && (activeCount > 5 || archivedCount > 0)
    }

    private func freeActiveLimitBanner(theme: AppTheme) -> some View {
        let activeCount = publicationModels.filter { !$0.isArchived }.count
        let archivedCount = publicationModels.filter { $0.isArchived }.count

        return HStack(spacing: AppSpacing.sm) {
            Image(systemName: "archivebox.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(activeCount)/5 documentos activos", comment: "Banner count title")
                    .font(AppTypography.caption.weight(.bold))
                    .foregroundStyle(AppColor.textPrimary(for: theme))

                if archivedCount > 0 {
                    Text("\(archivedCount) document\(archivedCount == 1 ? "o" : "os") archivado\(archivedCount == 1 ? "" : "s") conservando todas sus notas", comment: "Banner archived subtitle")
                        .font(.system(size: 10))
                        .foregroundStyle(AppColor.textSecondary(for: theme))
                }
            }

            Spacer()

            Button(String(localized: "Elegir 5", comment: "Banner button choose 5")) {
                showActiveSelector = true
            }
            .font(AppTypography.caption.weight(.bold))
            .foregroundStyle(AppColor.accent(for: theme))
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.vertical, AppSpacing.xs)
        .background(Color.orange.opacity(0.12))
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
                                handlePublicationTap(record)
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
                                handlePublicationTap(record)
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.vertical, AppSpacing.md)
                }
            }
        }
    }

    // MARK: - Actions

    private func handlePublicationTap(_ record: PublicationRecord) {
        if record.isArchived {
            selectedArchivedRecord = record
            showArchivedAlert = true
        } else {
            router.selectedPublication = record
        }
    }

    private func checkFreePlanActiveCount() {
        let isFree = !dependencies.subscriptionService.hasActiveSubscription
        if isFree {
            let activeModels = publicationModels.filter { !$0.isArchived }
            if activeModels.count > 5 {
                // Auto-archivar a partir del 6to documento más antiguo
                for (index, model) in activeModels.enumerated() {
                    if index >= 5 {
                        model.isArchived = true
                    }
                }
                try? modelContext.save()
            }
        }
    }

    // MARK: - Helpers

    private var hasDocuments: Bool {
        !publicationModels.isEmpty
    }

    private var filteredModels: [PublicationModel] {
        let filtered = publicationModels.filter { model in
            let record = model.toDomain()

            if !searchText.isEmpty {
                let matchesSearch = record.title.localizedCaseInsensitiveContains(searchText) ||
                    (record.author?.localizedCaseInsensitiveContains(searchText) ?? false)
                guard matchesSearch else { return false }
            }

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
            case .pptx:
                return record.publicationType == .pptx
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

        return filtered.sorted { a, b in
            if a.isPinned != b.isPinned {
                return a.isPinned && !b.isPinned
            }
            return a.createdAt > b.createdAt
        }
    }
}

// MARK: - LibraryFilter

enum LibraryFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case epub
    case pdf
    case pptx
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
        case .pptx: String(localized: "Diapositivas", comment: "Library filter: presentations")
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
        case .pptx: "rectangle.on.rectangle.angled"
        case .txt: "doc.text"
        case .markdown: "text.document"
        case .inProgress: "clock"
        case .finished: "checkmark.circle"
        case .notStarted: "circle"
        case .favorites: "heart"
        }
    }
}
