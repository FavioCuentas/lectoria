import SwiftUI

// MARK: - NotesView

/// Pantalla global de notas y destacados de Lectoria.
///
/// Permite listar, buscar y filtrar todas las anotaciones creadas en la aplicación.
/// Soporta categorías de estudio (.mainIdea, .question, etc.), navegación inmediata
/// al lector correspondiente en la posición exacta, y exportación consolidada en TXT y Markdown.
struct NotesView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppDependencies.self) private var dependencies

    // Datos globales de la base de datos
    @State private var highlights: [Highlight] = []
    @State private var notes: [Note] = []
    @State private var publications: [PublicationRecord] = []
    @State private var isLoading = true

    // Filtros y búsqueda
    @State private var searchText = ""
    @State private var selectedFilter: FilterTab = .all
    
    // Navegación al lector
    @State private var selectedPublication: PublicationRecord? = nil
    @State private var initialPDFLocation: PDFLocation? = nil
    @State private var initialTextLocation: TextLocation? = nil
    @State private var exportWrapper: ExportFileWrapper? = nil

    enum FilterTab: String, CaseIterable, Identifiable {
        case all = "Todos"
        case notes = "Notas"
        case aiQueries = "Consultas IA"
        var id: String { rawValue }
    }

    var body: some View {
        let theme = themeManager.currentTheme

        NavigationStack {
            ZStack {
                AppColor.background(for: theme)
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(AppColor.accent(for: theme))
                } else if filteredItems.isEmpty {
                    EmptyStateView(
                        icon: searchText.isEmpty ? "note.text" : "magnifyingglass",
                        title: searchText.isEmpty ? String(localized: "Sin notas todavía") : String(localized: "Sin resultados"),
                        subtitle: searchText.isEmpty
                            ? String(localized: "Las notas y destacados que crees mientras lees aparecerán aquí.")
                            : String(localized: "Intenta buscar otra palabra o etiqueta.")
                    )
                } else {
                    List {
                        ForEach(filteredItems) { item in
                            annotationCard(item, theme: theme)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await loadData()
                    }
                }
            }
            .navigationTitle(String(localized: "Notas"))
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Buscar en texto o etiquetas...")
            .toolbar {
                if !highlights.isEmpty || !notes.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            ForEach(NoteExportFormat.allCases) { format in
                                Button {
                                    exportNotes(format: format)
                                } label: {
                                    Label(format.displayName, systemImage: format.systemImage)
                                }
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(AppColor.accent(for: theme))
                        }
                    }
                }
            }
            .sheet(item: $exportWrapper) { wrapper in
                ShareSheetView(activityItems: [wrapper.url])
            }
            .safeAreaInset(edge: .top) {
                // Filtro segmentado de barra de herramientas superior
                Picker("Filtro", selection: $selectedFilter) {
                    ForEach(FilterTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.xs)
                .background(AppColor.background(for: theme))
            }
            .navigationDestination(item: $selectedPublication) { pub in
                switch pub.publicationType {
                case .pdf:
                    PDFReaderView(record: pub, initialLocation: initialPDFLocation)
                case .epub:
                    EPUBReaderView(record: pub)
                case .txt, .markdown, .pastedText, .pptx:
                    TextReaderView(record: pub, initialLocation: initialTextLocation)
                }
            }
            .task {
                await loadData()
            }
            .sheet(item: $editingItem) { item in
                EditAnnotationSheet(
                    highlight: item.highlight,
                    note: item.note
                ) { updatedHl, updatedNote in
                    Task {
                        if let hl = updatedHl {
                            try? await dependencies.highlightRepository.save(hl)
                        }
                        if let note = updatedNote {
                            try? await dependencies.noteRepository.save(note)
                        }
                        await loadData()
                    }
                } onDelete: {
                    deleteItem(item)
                }
            }
        }
    }

    // MARK: - Annotation Cards Renderer

    @ViewBuilder
    private func annotationCard(_ item: AnnotationItem, theme: AppTheme) -> some View {
        let pubTitle = publications.first(where: { $0.id == item.publicationID })?.title ?? "Libro desconocido"
        
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Encabezado con el libro, la fecha y el menú de acciones rápidas
            HStack {
                Text(pubTitle)
                    .font(AppTypography.captionBold)
                    .foregroundStyle(AppColor.accent(for: theme))
                    .lineLimit(1)
                
                Spacer()
                
                Text(item.date, style: .date)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.textTertiary(for: theme))
                
                Menu {
                    Button {
                        navigateToPosition(item)
                    } label: {
                        Label("Ir a la lectura", systemImage: "book")
                    }
                    Button {
                        editingItem = item
                    } label: {
                        Label("Editar", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        deleteItem(item)
                    } label: {
                        Label("Eliminar", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppColor.textSecondary(for: theme))
                        .padding(.leading, AppSpacing.xs)
                        .contentShape(Rectangle())
                }
            }

            if let highlight = item.highlight {
                // Cuerpo del destacado
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    HStack {
                        Text(highlight.category ?? "Destacado")
                            .font(AppTypography.captionBold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, 2)
                            .background(categoryColor(highlight.category))
                            .clipShape(Capsule())
                        
                        Spacer()
                    }

                    Text("\"\(highlight.selectedText)\"")
                        .font(AppTypography.body.italic())
                        .foregroundStyle(AppColor.textPrimary(for: theme))
                        .multilineTextAlignment(.leading)
                        .padding(AppSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(categoryColor(highlight.category).opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xs))
                }
            }

            if let note = item.note {
                // Cuerpo de la nota
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    if item.highlight != nil {
                        // Subtítulo indicador de nota vinculada
                        Text("Nota vinculada:")
                            .font(AppTypography.footnote.weight(.semibold))
                            .foregroundStyle(AppColor.textSecondary(for: theme))
                    }
                    
                    Text(note.body)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColor.textPrimary(for: theme))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if !note.tags.isEmpty {
                        // Etiquetas de la nota
                        HStack(spacing: AppSpacing.xs) {
                            ForEach(note.tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColor.textSecondary(for: theme))
                            }
                        }
                        .padding(.top, 2)
                    }
                }
            }
        }
        .padding(AppSpacing.md)
        .background(AppColor.surface(for: theme))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
        .shadow(color: AppShadow.subtle(for: theme).color,
                radius: AppShadow.subtle(for: theme).radius,
                x: AppShadow.subtle(for: theme).x,
                y: AppShadow.subtle(for: theme).y)
        .contentShape(RoundedRectangle(cornerRadius: AppRadius.sm))
        .onTapGesture {
            navigateToPosition(item)
        }
        .contextMenu {
            Button {
                navigateToPosition(item)
            } label: {
                Label("Ir a la lectura", systemImage: "book")
            }
            Button {
                editingItem = item
            } label: {
                Label("Editar", systemImage: "pencil")
            }
            Button(role: .destructive) {
                deleteItem(item)
            } label: {
                Label("Eliminar", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                deleteItem(item)
            } label: {
                Label("Eliminar", systemImage: "trash")
            }
            Button {
                editingItem = item
            } label: {
                Label("Editar", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }

    // MARK: - Filter and Helpers

    private var filteredItems: [AnnotationItem] {
        var items: [AnnotationItem] = []

        // Unificar destacados
        for hl in highlights {
            let note = notes.first { $0.highlightID == hl.id }
            items.append(AnnotationItem(id: hl.id, publicationID: hl.publicationID, highlight: hl, note: note, date: hl.createdAt))
        }

        // Agregar notas independientes (no vinculadas a destacados)
        for note in notes {
            if note.highlightID == nil {
                items.append(AnnotationItem(id: note.id, publicationID: note.publicationID, highlight: nil, note: note, date: note.createdAt))
            }
        }

        // Ordenar por fecha descendente
        items.sort { $0.date > $1.date }

        // Aplicar filtro de tipo
        switch selectedFilter {
        case .notes:
            // Mostrar solo notas normales redactadas por el usuario (no consultas IA)
            items = items.filter { item in
                guard item.note != nil else { return false }
                if let hl = item.highlight {
                    let cat = hl.category ?? ""
                    return cat != HighlightCategory.dictionary.rawValue &&
                           cat != HighlightCategory.translation.rawValue &&
                           cat != HighlightCategory.ai.rawValue
                }
                return true
            }
        case .aiQueries:
            // Mostrar solo consultas IA
            items = items.filter { item in
                if let hl = item.highlight {
                    let cat = hl.category ?? ""
                    return cat == HighlightCategory.dictionary.rawValue ||
                           cat == HighlightCategory.translation.rawValue ||
                           cat == HighlightCategory.ai.rawValue
                }
                return false
            }
        case .all:
            break
        }

        // Aplicar búsqueda por texto o tags
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let query = searchText.lowercased()
            items = items.filter { item in
                let matchesHighlight = item.highlight?.selectedText.lowercased().contains(query) ?? false
                let matchesCategory = item.highlight?.category?.lowercased().contains(query) ?? false
                let matchesNote = item.note?.body.lowercased().contains(query) ?? false
                let matchesTags = item.note?.tags.contains { $0.lowercased().contains(query) } ?? false
                let pubTitle = publications.first(where: { $0.id == item.publicationID })?.title.lowercased() ?? ""
                let matchesTitle = pubTitle.contains(query)
                
                return matchesHighlight || matchesCategory || matchesNote || matchesTags || matchesTitle
            }
        }

        return items
    }

    private func categoryColor(_ category: String?) -> Color {
        guard let category = category else { return .yellow }
        switch category {
        case "Idea principal": return .blue
        case "Duda": return .purple
        case "Evidencia": return .green
        case "Acción": return .orange
        case "Cita": return .pink
        case "Diccionario": return Color(red: 0.18, green: 0.60, blue: 0.60)
        case "Traducción": return Color(red: 0.36, green: 0.36, blue: 0.75)
        case "IA": return Color(red: 0.12, green: 0.53, blue: 0.82)
        default: return .yellow
        }
    }

    // MARK: - Database Actions

    private func loadData() async {
        do {
            self.publications = try await dependencies.publicationRepository.fetchAll()
            self.highlights = try await dependencies.highlightRepository.fetchAll()
            self.notes = try await dependencies.noteRepository.fetchAll()
            self.isLoading = false
        } catch {
            self.isLoading = false
        }
    }

    private func deleteItem(_ item: AnnotationItem) {
        Task {
            if let hl = item.highlight {
                try? await dependencies.highlightRepository.delete(id: hl.id)
            }
            if let note = item.note {
                try? await dependencies.noteRepository.delete(id: note.id)
            }
            await loadData()
        }
    }

    private func navigateToPosition(_ item: AnnotationItem) {
        guard let pub = publications.first(where: { $0.id == item.publicationID }) else { return }
        
        let anchorStr = item.highlight?.anchor ?? item.note?.anchor ?? ""
        guard let anchorData = anchorStr.data(using: .utf8) else { return }

        // Limpiar posiciones previas
        self.initialPDFLocation = nil
        self.initialTextLocation = nil

        switch pub.publicationType {
        case .pdf:
            if let decoded = try? JSONDecoder().decode(PDFLocation.self, from: anchorData) {
                self.initialPDFLocation = decoded
                self.selectedPublication = pub
            }
        case .txt, .markdown, .pastedText:
            if let decoded = try? JSONDecoder().decode(TextLocation.self, from: anchorData) {
                self.initialTextLocation = decoded
                self.selectedPublication = pub
            }
        default:
            self.selectedPublication = pub
        }
    }

    // MARK: - Export Logic

    private func exportNotes(format: NoteExportFormat) {
        var exportDataList: [NoteExportData] = []

        for pub in publications {
            let pubHighlights = highlights.filter { $0.publicationID == pub.id }
            let pubNotes = notes.filter { $0.publicationID == pub.id }
            if !pubHighlights.isEmpty || !pubNotes.isEmpty {
                exportDataList.append(NoteExportData(publication: pub, highlights: pubHighlights, notes: pubNotes))
            }
        }

        guard !exportDataList.isEmpty else { return }

        do {
            let url = try NoteExporter.export(data: exportDataList, format: format)
            self.exportWrapper = ExportFileWrapper(url: url)
        } catch {
            print("Error al exportar notas: \(error)")
        }
    }

    // MARK: - AnnotationItem Wrapper

    struct AnnotationItem: Identifiable {
        let id: UUID
        let publicationID: UUID
        let highlight: Highlight?
        let note: Note?
        let date: Date
    }
}

// MARK: - ExportFileWrapper

struct ExportFileWrapper: Identifiable {
    let id = UUID()
    let url: URL
}
