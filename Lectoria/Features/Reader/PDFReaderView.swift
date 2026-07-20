import SwiftUI
import PDFKit

// MARK: - PDFReaderView

/// Pantalla del lector de documentos PDF.
///
/// Integra `PDFReaderAdapter` y `PDFNavigatorWrapper` con el Design System de Lectoria,
/// ofreciendo soporte para zoom nativo, desplazamiento continuo vertical vs horizontal paginado,
/// visualizador horizontal de miniaturas, búsqueda de texto, marcadores y sincronización de progreso.
struct PDFReaderView: View {
    let record: PublicationRecord
    
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss

    // Estado del ciclo de vida del lector
    @State private var adapter = PDFReaderAdapter()
    @State private var isLoading = true
    @State private var loadingError: String? = nil
    
    // Referencia al PDFView nativo para asociar con miniaturas
    @State private var pdfViewReference: PDFView? = nil
    
    // Ubicación de lectura y navegación
    @State private var initialLocation: PDFLocation? = nil
    @State private var currentLocation: PDFLocation? = nil
    @State private var targetLocation: PDFLocation? = nil
    @State private var tocItems: [TOCItem] = []
    @State private var bookmarks: [Bookmark] = []
    
    // Anotaciones y Destacados
    @State private var highlights: [Highlight] = []
    @State private var selectedText = ""
    @State private var hasSelection = false
    @State private var showNoteEditor = false
    @State private var noteBody = ""
    @State private var noteTags = ""
    @State private var pendingCategory: HighlightCategory? = nil
    @State private var showPaywall = false
    @State private var showConsent = false
    @State private var pendingAIAction: String? = nil
    
    // Respuesta inline (globo flotante)
    @State private var showInlineBubble = false
    @State private var inlineBubbleTitle = ""
    @State private var inlineBubbleText = ""
    @State private var isLoadingInline = false

    init(record: PublicationRecord, initialLocation: PDFLocation? = nil) {
        self.record = record
        self._initialLocation = State(initialValue: initialLocation)
    }

    // Controles de interfaz de usuario
    @State private var showUI = true
    @State private var showTOC = false
    @State private var showSettings = false
    @State private var showSearch = false
    
    // Pestaña activa del índice (TOC vs Marcadores)
    @State private var tocTab: TOCTab = .outline
    
    // Búsqueda de texto
    @State private var searchQuery = ""
    @State private var searchResults: [SearchResult] = []
    @State private var isSearching = false

    // Preferencias del usuario (persistidas o inicializadas por defecto)
    @State private var isScrollMode = true

    enum TOCTab: String, CaseIterable, Identifiable {
        case outline = "Índice"
        case bookmarks = "Marcadores"
        
        var id: String { rawValue }
    }

    var body: some View {
        let appTheme = themeManager.currentTheme

        ZStack {
            // Fondo adaptado al tema actual de lectura
            AppColor.background(for: appTheme)
                .ignoresSafeArea()

            if isLoading {
                loadingView(theme: appTheme)
            } else if let error = loadingError {
                errorView(error, theme: appTheme)
            } else if let document = adapter.document {
                // Wrapper de PDFKit
                PDFNavigatorWrapper(
                    document: document,
                    initialLocation: initialLocation,
                    currentLocation: $currentLocation,
                    isScrollMode: isScrollMode,
                    selectedText: $selectedText,
                    hasSelection: $hasSelection,
                    highlights: highlights,
                    pdfViewBinding: $pdfViewReference,
                    onTap: { _ in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showUI.toggle()
                        }
                    },
                    targetLocation: targetLocation
                )
                .ignoresSafeArea(.all, edges: showUI ? [] : .all)
            }

            // Capa de Controles y Barras Superpuestas
            if !isLoading && loadingError == nil {
                overlaysView(theme: appTheme)
            }
            
            // Panel flotante de selección
            if hasSelection && !selectedText.isEmpty {
                selectionFloatingToolbar(theme: appTheme)
                    .transition(.opacity)
            }
            
            // Globo flotante de respuesta inline (Diccionario, Traducción, IA)
            if showInlineBubble {
                inlineResponseBubble(theme: appTheme)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(!showUI)
        .sheet(isPresented: $showNoteEditor) {
            noteEditorSheet(theme: appTheme)
        }
        .task {
            await loadPDF()
        }
        .onChange(of: currentLocation) { _, newValue in
            if let newValue {
                saveReadingProgress(location: newValue)
            }
        }
        .onDisappear {
            Task {
                await adapter.close()
            }
        }
    }

    // MARK: - Loading & Error States

    private func loadingView(theme: AppTheme) -> some View {
        VStack(spacing: AppSpacing.md) {
            ProgressView()
                .tint(AppColor.accent(for: theme))
            Text(String(localized: "Abriendo PDF…", comment: "Reader: loading PDF"))
                .font(AppTypography.callout)
                .foregroundStyle(AppColor.textSecondary(for: theme))
        }
    }

    private func errorView(_ message: String, theme: AppTheme) -> some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(AppColor.error(for: theme))
            
            Text(message)
                .font(AppTypography.body)
                .foregroundStyle(AppColor.textPrimary(for: theme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)

            Button {
                Task { await loadPDF() }
            } label: {
                Text(String(localized: "Reintentar", comment: "Reader: retry opening"))
                    .font(AppTypography.bodyBold)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, AppSpacing.md)
                    .background(AppColor.accent(for: theme))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
            }
        }
    }

    // MARK: - Overlays & Bars

    private func overlaysView(theme: AppTheme) -> some View {
        VStack {
            if showUI {
                // Barra Superior
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .padding(AppSpacing.md)
                            .foregroundStyle(AppColor.textPrimary(for: theme))
                    }
                    .accessibilityLabel("Volver a biblioteca")
                    
                    Spacer()
                    
                    Text(record.title)
                        .font(AppTypography.bodyBold)
                        .lineLimit(1)
                        .foregroundStyle(AppColor.textPrimary(for: theme))
                        .frame(maxWidth: 180)
                    
                    Spacer()
                    
                    // Botón para Marcadores (Bookmark)
                    Button {
                        toggleBookmark()
                    } label: {
                        Image(systemName: isCurrentPageBookmarked ? "bookmark.fill" : "bookmark")
                            .font(.title3)
                            .padding(AppSpacing.sm)
                            .foregroundStyle(isCurrentPageBookmarked ? AppColor.accent(for: theme) : AppColor.textPrimary(for: theme))
                    }
                    .accessibilityLabel(isCurrentPageBookmarked ? "Quitar marcador" : "Añadir marcador")
                    
                    // Botón de Búsqueda de Texto
                    Button {
                        showSearch.toggle()
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.title3)
                            .padding(AppSpacing.sm)
                            .foregroundStyle(AppColor.textPrimary(for: theme))
                    }
                    .accessibilityLabel("Buscar en documento")
                    
                    // Botón de Preferencias de lectura
                    Button {
                        showSettings.toggle()
                    } label: {
                        Image(systemName: "textformat")
                            .font(.title3)
                            .padding(AppSpacing.sm)
                            .foregroundStyle(AppColor.textPrimary(for: theme))
                    }
                    .accessibilityLabel("Opciones de lectura")
                    
                    // Botón del Índice / TOC
                    Button {
                        showTOC.toggle()
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.title3)
                            .padding(AppSpacing.sm)
                            .foregroundStyle(AppColor.textPrimary(for: theme))
                    }
                    .accessibilityLabel("Índice y marcadores")
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.top, safeAreaTop)
                .background(
                    AppColor.surface(for: theme)
                        .shadow(color: AppShadow.subtle(for: theme).color,
                                radius: AppShadow.subtle(for: theme).radius,
                                x: AppShadow.subtle(for: theme).x,
                                y: AppShadow.subtle(for: theme).y)
                )
                .transition(.move(edge: .top))
            }
            
            Spacer()
            
            if showUI {
                // Barra de Miniaturas (Visual Slider)
                if let pdfView = pdfViewReference {
                    VStack(spacing: 0) {
                        Divider()
                            .background(AppColor.border(for: theme))
                        
                        PDFThumbnailWrapper(pdfView: pdfView)
                            .frame(height: 64)
                            .padding(.vertical, AppSpacing.xs)
                            .background(AppColor.surfaceSecondary(for: theme))
                    }
                    .transition(.opacity)
                }

                // Barra Inferior (Progreso)
                VStack(spacing: AppSpacing.xs) {
                    let pageIndex = currentLocation?.pageIndex ?? 0
                    let totalPages = currentLocation?.totalPages ?? 1
                    let progressPercent = Double(pageIndex) / Double(max(1, totalPages - 1))
                    let pageLabel = currentLocation?.pageLabel ?? "\(pageIndex + 1)"
                    
                    HStack {
                        Text(String(localized: "Página \(pageLabel) de \(totalPages)", comment: "Reader: PDF page progression"))
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColor.textSecondary(for: theme))
                        
                        Spacer()
                        
                        Text(String(format: "%.0f%%", progressPercent * 100))
                            .font(AppTypography.captionBold)
                            .foregroundStyle(AppColor.textPrimary(for: theme))
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    
                    ProgressView(value: progressPercent, total: 1.0)
                        .tint(AppColor.accent(for: theme))
                        .padding(.horizontal, AppSpacing.lg)
                }
                .padding(.vertical, AppSpacing.md)
                .background(
                    AppColor.surface(for: theme)
                        .shadow(color: AppShadow.subtle(for: theme).color,
                                radius: AppShadow.subtle(for: theme).radius,
                                x: AppShadow.subtle(for: theme).x,
                                y: AppShadow.subtle(for: theme).y)
                )
                .transition(.move(edge: .bottom))
            }
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .tabBar)
        // Hojas secundarias
        .sheet(isPresented: $showTOC) {
            tocSheet(theme: theme)
        }
        .sheet(isPresented: $showSettings) {
            settingsSheet(theme: theme)
        }
        .sheet(isPresented: $showSearch) {
            searchSheet(theme: theme)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showConsent) {
            AIConsentView { accepted in
                if accepted, let pending = pendingAIAction {
                    executeInlineAI(action: pending)
                }
            }
        }
    }

    // MARK: - Table of Contents & Bookmarks Sheet

    private func tocSheet(theme: AppTheme) -> some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented Control para Índice vs Marcadores
                Picker("Vista", selection: $tocTab) {
                    ForEach(TOCTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(AppSpacing.md)
                .background(AppColor.surface(for: theme))
                
                Divider()
                    .background(AppColor.border(for: theme))
                
                if tocTab == .outline {
                    if tocItems.isEmpty {
                        VStack(spacing: AppSpacing.sm) {
                            Spacer()
                            Image(systemName: "list.bullet.rectangle.portrait")
                                .font(.largeTitle)
                                .foregroundStyle(AppColor.textTertiary(for: theme))
                            Text("Este PDF no tiene índice de contenidos.")
                                .font(AppTypography.callout)
                                .foregroundStyle(AppColor.textSecondary(for: theme))
                            Spacer()
                        }
                    } else {
                        List(tocItems) { item in
                            Button {
                                if !item.locationData.isEmpty,
                                   let location = try? JSONDecoder().decode(PDFLocation.self, from: item.locationData) {
                                    targetLocation = location
                                    showTOC = false
                                }
                            } label: {
                                HStack {
                                    Text(item.title)
                                        .font(AppTypography.body)
                                        .foregroundStyle(AppColor.textPrimary(for: theme))
                                    Spacer()
                                }
                            }
                            .listRowBackground(AppColor.surface(for: theme))
                        }
                        .scrollContentBackground(.hidden)
                    }
                } else {
                    if bookmarks.isEmpty {
                        VStack(spacing: AppSpacing.sm) {
                            Spacer()
                            Image(systemName: "bookmark")
                                .font(.largeTitle)
                                .foregroundStyle(AppColor.textTertiary(for: theme))
                            Text("Aún no has agregado ningún marcador.")
                                .font(AppTypography.callout)
                                .foregroundStyle(AppColor.textSecondary(for: theme))
                            Spacer()
                        }
                    } else {
                        List(bookmarks) { bookmark in
                            Button {
                                if let data = bookmark.anchor.data(using: .utf8),
                                   let location = try? JSONDecoder().decode(PDFLocation.self, from: data) {
                                    targetLocation = location
                                    showTOC = false
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                        Text(bookmark.title ?? "Marcador")
                                            .font(AppTypography.bodyBold)
                                            .foregroundStyle(AppColor.textPrimary(for: theme))
                                        Text(bookmark.createdAt, style: .date)
                                            .font(AppTypography.caption)
                                            .foregroundStyle(AppColor.textSecondary(for: theme))
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(AppColor.textTertiary(for: theme))
                                }
                            }
                            .listRowBackground(AppColor.surface(for: theme))
                            .swipeActions {
                                Button(role: .destructive) {
                                    deleteBookmark(bookmark)
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .background(AppColor.background(for: theme))
            .navigationTitle("Índice de contenidos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { showTOC = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task {
            await loadBookmarks()
        }
    }

    // MARK: - Settings Sheet (Format & Theme)

    private func settingsSheet(theme: AppTheme) -> some View {
        VStack(spacing: AppSpacing.xl) {
            Text("Opciones de lectura")
                .font(AppTypography.title2)
                .foregroundStyle(AppColor.textPrimary(for: theme))
                .padding(.top, AppSpacing.lg)

            // Selector de Tema
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Tema del lector")
                    .font(AppTypography.footnote)
                    .foregroundStyle(AppColor.textSecondary(for: theme))
                
                HStack(spacing: AppSpacing.md) {
                    ForEach(AppTheme.allCases) { item in
                        Button {
                            withAnimation {
                                themeManager.currentTheme = item
                            }
                        } label: {
                            Text(item.displayName)
                                .font(AppTypography.callout)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppSpacing.sm)
                                .background(themeManager.currentTheme == item ? AppColor.accent(for: theme) : AppColor.surfaceSecondary(for: theme))
                                .foregroundStyle(themeManager.currentTheme == item ? .white : AppColor.textPrimary(for: theme))
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.sm)
                                        .stroke(AppColor.border(for: theme), lineWidth: 1)
                                )
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)

            // Dirección de Lectura (Scroll vs Páginas)
            Toggle(isOn: $isScrollMode) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("Desplazamiento continuo")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColor.textPrimary(for: theme))
                    Text("Desplazar verticalmente en lugar de paginar horizontalmente")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColor.textSecondary(for: theme))
                }
            }
            .tint(AppColor.accent(for: theme))
            .padding(.horizontal, AppSpacing.lg)

            Spacer()
        }
        .padding(.bottom, AppSpacing.xxl)
        .background(AppColor.surface(for: theme))
        .presentationDetents([.height(280)])
    }

    // MARK: - Search Sheet

    private func searchSheet(theme: AppTheme) -> some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Barra de Búsqueda
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(AppColor.textSecondary(for: theme))
                    
                    TextField("Buscar texto en el libro...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .foregroundStyle(AppColor.textPrimary(for: theme))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit {
                            performSearch()
                        }
                    
                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                            searchResults.removeAll()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(AppColor.textSecondary(for: theme))
                        }
                    }
                }
                .padding(AppSpacing.md)
                .background(AppColor.surfaceSecondary(for: theme))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.sm)
                
                Divider()
                    .background(AppColor.border(for: theme))
                
                if isSearching {
                    VStack {
                        Spacer()
                        ProgressView()
                            .tint(AppColor.accent(for: theme))
                        Text("Buscando...")
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColor.textSecondary(for: theme))
                            .padding(.top, AppSpacing.xs)
                        Spacer()
                    }
                } else if searchResults.isEmpty && !searchQuery.isEmpty {
                    VStack {
                        Spacer()
                        Text("No se encontraron resultados.")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColor.textSecondary(for: theme))
                        Spacer()
                    }
                } else {
                    List(searchResults) { result in
                        Button {
                            if !result.locationData.isEmpty,
                               let location = try? JSONDecoder().decode(PDFLocation.self, from: result.locationData) {
                                targetLocation = location
                                showSearch = false
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                Text(result.chapterTitle ?? "Página")
                                    .font(AppTypography.footnote.weight(.semibold))
                                    .foregroundStyle(AppColor.accent(for: theme))
                                
                                Text(result.text)
                                    .font(AppTypography.body)
                                    .foregroundStyle(AppColor.textPrimary(for: theme))
                                    .lineLimit(2)
                            }
                        }
                        .listRowBackground(AppColor.surface(for: theme))
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(AppColor.background(for: theme))
            .navigationTitle("Buscar en el PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { showSearch = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Book Lifecycle & Operations

    private func loadPDF() async {
        isLoading = true
        loadingError = nil
        
        do {
            // 1. Cargar el último progreso guardado de la base de datos
            if let savedProgress = try? await dependencies.readingProgressRepository.fetchProgress(forPublication: record.id),
               let data = savedProgress.locatorJSON.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(PDFLocation.self, from: data) {
                self.initialLocation = decoded
                self.currentLocation = decoded
            }
            
            // 2. Abrir el PDF con el adaptador
            try await adapter.open(publication: record)
            
            // Registrar fecha de apertura
            var updatedRecord = record
            updatedRecord.lastOpenedAt = Date()
            try? await dependencies.publicationRepository.save(updatedRecord)
            
            // 3. Extraer el outline (TOC)
            self.tocItems = (try? await adapter.tableOfContents()) ?? []
            
            // 4. Cargar marcadores locales
            await loadBookmarks()
            
            // 5. Cargar destacados de base de datos
            await loadHighlights()
            
            self.isLoading = false
        } catch {
            self.loadingError = error.localizedDescription
            self.isLoading = false
        }
    }

    private func loadHighlights() async {
        if let list = try? await dependencies.highlightRepository.fetch(forPublication: record.id) {
            await MainActor.run {
                self.highlights = list
            }
        }
    }

    /// Colores vibrantes y opacos para los botones circulares de la barra flotante.
    private func categoryColor(_ category: HighlightCategory) -> Color {
        switch category {
        case .mainIdea: return Color(red: 0.30, green: 0.55, blue: 0.80)   // Azul
        case .question: return Color(red: 0.55, green: 0.38, blue: 0.75)   // Púrpura
        case .evidence: return Color(red: 0.25, green: 0.65, blue: 0.45)   // Verde
        case .action:   return Color(red: 0.85, green: 0.47, blue: 0.34)   // Coral
        case .quote:    return Color(red: 0.80, green: 0.42, blue: 0.55)   // Rosa
        }
    }
    
    private func categoryColorToken(_ category: HighlightCategory) -> String {
        switch category {
        case .mainIdea: return "mainIdea"
        case .question: return "question"
        case .evidence: return "evidence"
        case .action: return "action"
        case .quote: return "quote"
        }
    }

    private func createHighlight(category: HighlightCategory, customNoteBody: String? = nil) {
        // Calcular ubicación: usar currentLocation si existe; de lo contrario, leerla del PDFView actual
        let current: PDFLocation
        if let loc = currentLocation {
            current = loc
        } else if let pdfView = pdfViewReference,
                  let doc = pdfView.document,
                  let page = pdfView.currentPage {
            let idx = doc.index(for: page)
            current = PDFLocation(pageIndex: idx, totalPages: doc.pageCount, pageLabel: page.label)
            // Sincronizar el estado
            self.currentLocation = current
        } else {
            return
        }
        
        let colorToken = categoryColorToken(category)
        
        // Capturar las coordenadas geométricas de la selección actual
        var boundsArray: [Double]? = nil
        if let pdfView = pdfViewReference,
           let selection = pdfView.currentSelection,
           let page = selection.pages.first {
            let bounds = selection.bounds(for: page)
            boundsArray = [Double(bounds.origin.x), Double(bounds.origin.y), Double(bounds.size.width), Double(bounds.size.height)]
        }
        
        let locWithBounds = PDFLocation(
            pageIndex: current.pageIndex,
            totalPages: current.totalPages,
            pageLabel: current.pageLabel,
            selectionBounds: boundsArray
        )
        
        let anchorData = (try? JSONEncoder().encode(locWithBounds)) ?? Data()
        let anchorStr = String(data: anchorData, encoding: .utf8) ?? ""
        
        let highlight = Highlight(
            publicationID: record.id,
            anchor: anchorStr,
            selectedText: selectedText,
            category: category.rawValue,
            colorToken: colorToken
        )
        
        Task {
            // Validar límites del plan gratuito
            let canHighlight = await dependencies.entitlementService.canPerformAction(.createHighlight)
            guard canHighlight else {
                await MainActor.run {
                    self.showPaywall = true
                }
                return
            }
            
            // Si hay una nota asociada, validar límites de notas
            if let customNoteBody, !customNoteBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let canNote = await dependencies.entitlementService.canPerformAction(.createNote)
                guard canNote else {
                    await MainActor.run {
                        self.showPaywall = true
                    }
                    return
                }
            }

            // Guardar el destacado
            try? await dependencies.highlightRepository.save(highlight)
            
            // Si hay una nota asociada, guardarla
            if let customNoteBody, !customNoteBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let tagsArray = noteTags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                
                let note = Note(
                    publicationID: record.id,
                    highlightID: highlight.id,
                    anchor: anchorStr,
                    body: customNoteBody,
                    tags: tagsArray
                )
                try? await dependencies.noteRepository.save(note)
            }
            
            // Limpiar selección y refrescar destacados
            await MainActor.run {
                pdfViewReference?.clearSelection()
                hasSelection = false
                selectedText = ""
            }
            await loadHighlights()
        }
    }
    
    private func triggerAIAction(_ actionName: String) {
        Task {
            let canPerform = await dependencies.entitlementService.canPerformAction(.performAIAction)
            guard canPerform else {
                await MainActor.run {
                    self.showPaywall = true
                }
                return
            }
            
            if !dependencies.aiService.hasConsentedToAI {
                await MainActor.run {
                    self.pendingAIAction = actionName
                    self.showConsent = true
                }
            } else {
                executeInlineAI(action: actionName)
            }
        }
    }
    
    /// Ejecuta la acción de IA y muestra el resultado en el globo flotante inline.
    private func executeInlineAI(action: String) {
        let textToProcess = selectedText
        
        // Configurar título según la acción
        let title: String
        if action.hasPrefix("translate") {
            title = "🌐 Traducción"
        } else {
            switch action {
            case "define":     title = "📖 Definición"
            case "explain":    title = "💡 Explicación"
            case "simplify":   title = "✏️ Simplificado"
            case "summarize":  title = "📄 Resumen"
            case "generateQuestions": title = "❓ Preguntas"
            default:           title = "✨ IA"
            }
        }
        
        withAnimation(.spring(response: 0.3)) {
            inlineBubbleTitle = title
            inlineBubbleText = ""
            isLoadingInline = true
            showInlineBubble = true
        }
        
        Task {
            let token = dependencies.authService.sessionToken
            do {
                let result: String
                if action.hasPrefix("translate_") {
                    let langCode = String(action.dropFirst("translate_".count))
                    result = try await dependencies.aiService.translate(text: textToProcess, targetLanguage: langCode, sessionToken: token)
                } else {
                switch action {
                case "define":
                    result = try await dependencies.aiService.explain(text: "Define la palabra: \(textToProcess)", sessionToken: token)
                case "explain":
                    result = try await dependencies.aiService.explain(text: textToProcess, sessionToken: token)
                case "simplify":
                    result = try await dependencies.aiService.simplify(text: textToProcess, sessionToken: token)
                case "summarize":
                    result = try await dependencies.aiService.summarize(text: textToProcess, sessionToken: token)
                case "generateQuestions":
                    result = try await dependencies.aiService.generateQuestions(text: textToProcess, sessionToken: token)
                default:
                    result = ""
                }
                }
                
                // Registrar consumo de IA
                let usage = AIUsage(
                    id: UUID(),
                    userID: dependencies.authService.currentUser?.id,
                    operation: action,
                    creditCost: 1
                )
                try? await dependencies.aiUsageRepository.save(usage)
                
                await MainActor.run {
                    withAnimation(.spring(response: 0.3)) {
                        self.inlineBubbleText = result
                        self.isLoadingInline = false
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation(.spring(response: 0.3)) {
                        self.inlineBubbleText = "Error: \(error.localizedDescription)"
                        self.isLoadingInline = false
                    }
                }
            }
        }
    }

    private func selectionFloatingToolbar(theme: AppTheme) -> some View {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let circleSize: CGFloat = isPad ? 40 : 32
        
        return VStack {
            Spacer()
            
            VStack(spacing: isPad ? AppSpacing.md : AppSpacing.sm) {
                // Fila 1: Colores de subrayado
                HStack(spacing: isPad ? AppSpacing.lg : AppSpacing.md) {
                    ForEach(HighlightCategory.allCases, id: \.self) { category in
                        Button {
                            createHighlight(category: category)
                        } label: {
                            Circle()
                                .fill(categoryColor(category))
                                .frame(width: circleSize, height: circleSize)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                )
                                .shadow(radius: 2)
                        }
                    }
                    
                    Divider()
                        .frame(height: isPad ? 32 : 24)
                    
                    // Botón Nota
                    Button {
                        noteBody = ""
                        noteTags = ""
                        pendingCategory = nil
                        showNoteEditor = true
                    } label: {
                        Image(systemName: "note.text.badge.plus")
                            .font(isPad ? .title3 : .body)
                            .foregroundStyle(AppColor.textPrimary(for: theme))
                            .padding(AppSpacing.xs)
                    }
                    
                    // Cerrar selección
                    Button {
                        pdfViewReference?.clearSelection()
                        hasSelection = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(isPad ? .title3 : .body)
                            .foregroundStyle(AppColor.textSecondary(for: theme))
                            .padding(AppSpacing.xs)
                    }
                }
                
                // Fila 2: Diccionario, Traducir, Acciones IA
                HStack(spacing: isPad ? AppSpacing.xl : AppSpacing.lg) {
                    // Diccionario del sistema
                    Button {
                        showDictionary(for: selectedText)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "character.book.closed")
                                .font(isPad ? .body : .callout)
                            Text("Diccionario")
                                .font(isPad ? AppTypography.body : AppTypography.caption)
                        }
                        .foregroundStyle(AppColor.textPrimary(for: theme))
                        .padding(.horizontal, isPad ? AppSpacing.md : AppSpacing.sm)
                        .padding(.vertical, isPad ? AppSpacing.xs : AppSpacing.xxs)
                        .background(AppColor.surfaceSecondary(for: theme))
                        .clipShape(Capsule())
                    }
                    
                    // Traducción con selector de idioma
                    Menu {
                        Button(action: { triggerAIAction("translate_en") }) {
                            Label("Inglés", systemImage: "globe.americas")
                        }
                        Button(action: { triggerAIAction("translate_fr") }) {
                            Label("Francés", systemImage: "globe.europe.africa")
                        }
                        Button(action: { triggerAIAction("translate_pt") }) {
                            Label("Portugués", systemImage: "globe.americas")
                        }
                        Button(action: { triggerAIAction("translate_de") }) {
                            Label("Alemán", systemImage: "globe.europe.africa")
                        }
                        Button(action: { triggerAIAction("translate_it") }) {
                            Label("Italiano", systemImage: "globe.europe.africa")
                        }
                        Button(action: { triggerAIAction("translate_ja") }) {
                            Label("Japonés", systemImage: "globe.asia.australia")
                        }
                        Button(action: { triggerAIAction("translate_zh") }) {
                            Label("Chino", systemImage: "globe.asia.australia")
                        }
                        Button(action: { triggerAIAction("translate_ko") }) {
                            Label("Coreano", systemImage: "globe.asia.australia")
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "translate")
                                .font(isPad ? .body : .callout)
                            Text("Traducir")
                                .font(isPad ? AppTypography.body : AppTypography.caption)
                        }
                        .foregroundStyle(AppColor.textPrimary(for: theme))
                        .padding(.horizontal, isPad ? AppSpacing.md : AppSpacing.sm)
                        .padding(.vertical, isPad ? AppSpacing.xs : AppSpacing.xxs)
                        .background(AppColor.surfaceSecondary(for: theme))
                        .clipShape(Capsule())
                    }
                    
                    // Menú de IA
                    Menu {
                        Button(action: { triggerAIAction("explain") }) {
                            Label("Explicar", systemImage: "lightbulb")
                        }
                        Button(action: { triggerAIAction("simplify") }) {
                            Label("Simplificar", systemImage: "text.alignleft")
                        }
                        Button(action: { triggerAIAction("summarize") }) {
                            Label("Resumir", systemImage: "doc.text")
                        }
                        Button(action: { triggerAIAction("generateQuestions") }) {
                            Label("Crear preguntas", systemImage: "questionmark.circle")
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(isPad ? .body : .callout)
                            Text("IA")
                                .font(isPad ? AppTypography.bodyBold : AppTypography.caption.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, isPad ? AppSpacing.md : AppSpacing.sm)
                        .padding(.vertical, isPad ? AppSpacing.xs : AppSpacing.xxs)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.55, green: 0.38, blue: 0.85),
                                    Color(red: 0.85, green: 0.47, blue: 0.34)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, isPad ? AppSpacing.xl : AppSpacing.lg)
            .padding(.vertical, isPad ? AppSpacing.md : AppSpacing.sm)
            .background(AppColor.surface(for: theme))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .shadow(color: AppShadow.medium(for: theme).color,
                    radius: AppShadow.medium(for: theme).radius,
                    x: AppShadow.medium(for: theme).x,
                    y: AppShadow.medium(for: theme).y)
            .frame(maxWidth: isPad ? 650 : .infinity)
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, 90)
        }
    }

    /// Globo flotante que muestra la respuesta de Diccionario, Traducción o IA inline.
    private func inlineResponseBubble(theme: AppTheme) -> some View {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        
        return VStack {
            Spacer()
            
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                // Cabecera: título + botón cerrar + botón copiar
                HStack {
                    Text(inlineBubbleTitle)
                        .font(isPad ? AppTypography.title : AppTypography.bodyBold)
                        .foregroundStyle(AppColor.textPrimary(for: theme))
                    
                    Spacer()
                    
                    if !isLoadingInline && !inlineBubbleText.isEmpty {
                        Button {
                            UIPasteboard.general.string = inlineBubbleText
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(isPad ? .body : .caption)
                                .foregroundStyle(AppColor.textSecondary(for: theme))
                        }
                    }
                    
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            showInlineBubble = false
                            inlineBubbleText = ""
                            isLoadingInline = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(isPad ? .title3 : .body)
                            .foregroundStyle(AppColor.textTertiary(for: theme))
                    }
                }
                
                // Texto de origen (grounding)
                Text("\"\(selectedText.prefix(120))\"")
                    .font(isPad ? AppTypography.body : AppTypography.caption)
                    .foregroundStyle(AppColor.textTertiary(for: theme))
                    .lineLimit(2)
                
                Divider()
                
                // Contenido: loading o respuesta
                if isLoadingInline {
                    HStack(spacing: AppSpacing.sm) {
                        ProgressView()
                            .scaleEffect(isPad ? 1.0 : 0.8)
                            .tint(AppColor.accent(for: theme))
                        Text("Procesando…")
                            .font(isPad ? AppTypography.body : AppTypography.caption)
                            .foregroundStyle(AppColor.textSecondary(for: theme))
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, AppSpacing.sm)
                } else {
                    ScrollView {
                        Text(inlineBubbleText)
                            .font(isPad ? AppTypography.body : AppTypography.body)
                            .foregroundStyle(AppColor.textPrimary(for: theme))
                            .lineSpacing(isPad ? 6 : 4)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: isPad ? 350 : 200)
                    
                    // Botón guardar como nota
                    Button {
                        createHighlight(category: .mainIdea, customNoteBody: inlineBubbleText)
                        withAnimation(.spring(response: 0.3)) {
                            showInlineBubble = false
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "note.text.badge.plus")
                                .font(isPad ? .body : .caption)
                            Text("Guardar como nota")
                                .font(isPad ? AppTypography.bodyBold : AppTypography.caption.weight(.medium))
                        }
                        .foregroundStyle(AppColor.accent(for: theme))
                        .padding(.horizontal, isPad ? AppSpacing.md : AppSpacing.sm)
                        .padding(.vertical, isPad ? AppSpacing.xs : AppSpacing.xxs)
                        .background(AppColor.accent(for: theme).opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(isPad ? AppSpacing.lg : AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(AppColor.surface(for: theme))
                    .shadow(color: AppShadow.medium(for: theme).color,
                            radius: AppShadow.medium(for: theme).radius + 2,
                            x: AppShadow.medium(for: theme).x,
                            y: AppShadow.medium(for: theme).y)
            )
            .frame(maxWidth: isPad ? 650 : .infinity)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, hasSelection ? (isPad ? 230 : 200) : 90)
        }
    }

    /// Busca la definición de la palabra seleccionada usando IA e inline.
    private func showDictionary(for term: String) {
        let word = term.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines).first ?? term
        guard !word.isEmpty else { return }
        executeInlineAI(action: "define")
    }

    private func noteEditorSheet(theme: AppTheme) -> some View {
        NavigationStack {
            VStack(spacing: AppSpacing.md) {
                Picker("Categoría", selection: Binding(
                    get: { pendingCategory ?? .mainIdea },
                    set: { pendingCategory = $0 }
                )) {
                    ForEach(HighlightCategory.allCases, id: \.self) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
                
                TextEditor(text: $noteBody)
                    .font(AppTypography.body)
                    .padding(AppSpacing.sm)
                    .background(AppColor.surfaceSecondary(for: theme))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                    .padding(.horizontal, AppSpacing.lg)
                    .overlay(
                        VStack {
                            if noteBody.isEmpty {
                                HStack {
                                    Text("Escribe tu nota aquí...")
                                        .foregroundStyle(AppColor.textTertiary(for: theme))
                                        .padding(.leading, AppSpacing.xl + 4)
                                        .padding(.top, AppSpacing.lg)
                                    Spacer()
                                }
                                Spacer()
                            }
                        }
                    )
                
                TextField("Etiquetas (separadas por coma, ej: examen, física)", text: $noteTags)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.xl)
            }
            .background(AppColor.background(for: theme))
            .navigationTitle("Crear nota vinculada")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        showNoteEditor = false
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") {
                        let selectedCat = pendingCategory ?? .mainIdea
                        createHighlight(category: selectedCat, customNoteBody: noteBody)
                        showNoteEditor = false
                    }
                    .disabled(noteBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveReadingProgress(location: PDFLocation) {
        Task {
            let total = location.totalPages ?? 1
            let percentage = Double(location.pageIndex) / Double(max(1, total - 1))
            let chapterTitle = location.pageLabel != nil ? "Página \(location.pageLabel!)" : "Página \(location.pageIndex + 1)"
            let locatorJSON = (try? String(data: JSONEncoder().encode(location), encoding: .utf8)) ?? ""
            
            let progress = ReadingProgress(
                publicationID: record.id,
                locatorJSON: locatorJSON,
                percentage: percentage,
                pageNumber: location.pageIndex + 1,
                chapterTitle: chapterTitle,
                deviceID: "iOS-Simulator",
                version: 1
            )
            try? await dependencies.readingProgressRepository.saveProgress(progress)
        }
    }

    // MARK: - Bookmarks Logic

    private func loadBookmarks() async {
        if let list = try? await dependencies.bookmarkRepository.fetch(forPublication: record.id) {
            self.bookmarks = list
        }
    }

    private var isCurrentPageBookmarked: Bool {
        guard let current = currentLocation else { return false }
        return bookmarks.contains { bookmark in
            if let data = bookmark.anchor.data(using: .utf8),
               let location = try? JSONDecoder().decode(PDFLocation.self, from: data) {
                return location.pageIndex == current.pageIndex
            }
            return false
        }
    }

    private func toggleBookmark() {
        guard let current = currentLocation else { return }
        
        Task {
            if isCurrentPageBookmarked {
                // Eliminar marcador
                let bookmarkToDelete = bookmarks.first { bookmark in
                    if let data = bookmark.anchor.data(using: .utf8),
                       let location = try? JSONDecoder().decode(PDFLocation.self, from: data) {
                        return location.pageIndex == current.pageIndex
                    }
                    return false
                }
                
                if let bookmark = bookmarkToDelete {
                    try? await dependencies.bookmarkRepository.delete(id: bookmark.id)
                }
            } else {
                // Crear marcador
                let label = current.pageLabel != nil ? "Página \(current.pageLabel!)" : "Página \(current.pageIndex + 1)"
                let anchorData = (try? JSONEncoder().encode(current)) ?? Data()
                let anchorStr = String(data: anchorData, encoding: .utf8) ?? ""
                
                let bookmark = Bookmark(
                    publicationID: record.id,
                    anchor: anchorStr,
                    title: label
                )
                
                try? await dependencies.bookmarkRepository.save(bookmark)
            }
            
            // Recargar
            await loadBookmarks()
        }
    }

    private func deleteBookmark(_ bookmark: Bookmark) {
        Task {
            try? await dependencies.bookmarkRepository.delete(id: bookmark.id)
            await loadBookmarks()
        }
    }

    // MARK: - Search Logic

    private func performSearch() {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSearching = true
        searchResults.removeAll()
        
        Task {
            do {
                let results = try await adapter.search(searchQuery)
                await MainActor.run {
                    self.searchResults = results
                    self.isSearching = false
                }
            } catch {
                await MainActor.run {
                    self.isSearching = false
                }
            }
        }
    }

    // MARK: - Helpers

    private var safeAreaTop: CGFloat {
        let topInset = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .safeAreaInsets.top ?? 24
        return max(topInset, 24)
    }
}
