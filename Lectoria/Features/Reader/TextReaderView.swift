import SwiftUI

// MARK: - TextReaderView

/// Pantalla del lector de archivos de texto plano y Markdown.
///
/// Implementa un renderizador estructurado por bloques de texto (`TextBlock`)
/// que se cargan perezosamente, garantizando un rendimiento óptimo.
/// Soporta preferencias de formato (Serif vs. Sans-Serif, escala de fuente),
/// temas adaptativos, búsqueda interna, marcadores y progreso exacto.
struct TextReaderView: View {
    let record: PublicationRecord

    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss

    // Estado del ciclo de vida del lector
    @State private var adapter = TextReaderAdapter()
    @State private var isLoading = true
    @State private var loadingError: String? = nil

    // Ubicación de lectura y navegación
    @State private var initialLocation: TextLocation? = nil
    @State private var currentLocation: TextLocation? = nil
    @State private var targetLocation: TextLocation? = nil
    @State private var tocItems: [TOCItem] = []
    @State private var bookmarks: [Bookmark] = []
    
    // Anotaciones y Destacados
    @State private var highlights: [Highlight] = []
    @State private var showNoteEditor = false
    @State private var noteBody = ""
    @State private var noteTags = ""
    @State private var pendingCategory: HighlightCategory? = nil
    @State private var selectedBlockIndex: Int? = nil
    @State private var showPaywall = false
    @State private var showConsent = false
    @State private var showAIResponse = false
    @State private var pendingAIAction: String? = nil
    @State private var textToProcess = ""

    init(record: PublicationRecord, initialLocation: TextLocation? = nil) {
        self.record = record
        self._initialLocation = State(initialValue: initialLocation)
    }

    // Control de visibilidad de bloques en pantalla
    @State private var visibleIndices = Set<Int>()

    // Controles de interfaz de usuario
    @State private var showUI = true
    @State private var showTOC = false
    @State private var showSettings = false
    @State private var showSearch = false
    @State private var tocTab: TOCTab = .outline

    // Búsqueda de texto
    @State private var searchQuery = ""
    @State private var searchResults: [SearchResult] = []
    @State private var isSearching = false

    // Preferencias del usuario (persistidas o inicializadas por defecto)
    @State private var useSerif = true
    @State private var fontSizeMultiplier: Double = 1.0

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
            } else {
                // ScrollView con lector programático de posiciones
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: AppSpacing.md) {
                            ForEach(adapter.blocks) { block in
                                blockView(block)
                                    .id(block.index)
                                    .onAppear {
                                        visibleIndices.insert(block.index)
                                        updateCurrentLocation()
                                    }
                                    .onDisappear {
                                        visibleIndices.remove(block.index)
                                        updateCurrentLocation()
                                    }
                            }
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .padding(.top, showUI ? 100 : 40)
                        .padding(.bottom, 120)
                    }
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showUI.toggle()
                        }
                    }
                    .onChange(of: targetLocation) { _, newValue in
                        if let target = newValue {
                            withAnimation {
                                proxy.scrollTo(target.blockIndex, anchor: .top)
                            }
                        }
                    }
                }
            }

            // Capa de Controles y Barras Superpuestas
            if !isLoading && loadingError == nil {
                overlaysView(theme: appTheme)
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(!showUI)
        .task {
            await loadText()
        }
        .onChange(of: currentLocation) { _, newValue in
            if let newValue {
                saveReadingProgress(location: newValue)
            }
        }
    }

    // MARK: - Loading & Error States

    private func loadingView(theme: AppTheme) -> some View {
        VStack(spacing: AppSpacing.md) {
            ProgressView()
                .tint(AppColor.accent(for: theme))
            Text(String(localized: "Procesando documento…", comment: "Reader: loading text"))
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
                Task { await loadText() }
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
                // Barra Inferior (Progreso)
                VStack(spacing: AppSpacing.xs) {
                    let currentBlockIndex = currentLocation?.blockIndex ?? 0
                    let totalBlocks = adapter.blocks.count
                    let progressPercent = totalBlocks > 1 ? Double(currentBlockIndex) / Double(totalBlocks - 1) : 0.0

                    HStack {
                        Text(String(localized: "Progreso: Párrafo \(currentBlockIndex + 1) de \(totalBlocks)", comment: "Reader: Text paragraph progression"))
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
        .sheet(isPresented: $showNoteEditor) {
            noteEditorSheet(theme: theme)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showConsent) {
            AIConsentView { accepted in
                if accepted, let pending = pendingAIAction {
                    showAIResponse = true
                }
            }
        }
        .sheet(isPresented: $showAIResponse) {
            if let action = pendingAIAction {
                AIResponseSheet(
                    actionName: action,
                    textToProcess: textToProcess,
                    targetLanguage: action == "translate" ? "en" : nil,
                    onSaveAsNote: { responseText in
                        if let idx = selectedBlockIndex {
                            createHighlight(category: .mainIdea, blockIndex: idx, text: textToProcess, customNoteBody: responseText)
                        } else {
                            createHighlight(category: .mainIdea, blockIndex: 0, text: textToProcess, customNoteBody: responseText)
                        }
                    }
                )
            }
        }
    }

    // MARK: - Block rendering in SwiftUI

    @ViewBuilder
    private func blockView(_ block: TextBlock) -> some View {
        let theme = themeManager.currentTheme
        let baseSize: CGFloat = 16.0 * fontSizeMultiplier
        let highlight = activeHighlight(for: block.index)
        let highlightBgColor = categoryColorName(highlight?.colorToken)

        Group {
            switch block.type {
            case let .heading(text, level):
                Text(text)
                    .font(.system(size: baseSize * (2.2 - CGFloat(level) * 0.2), weight: .bold, design: .serif))
                    .foregroundStyle(AppColor.textPrimary(for: theme))
                    .padding(.top, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.xs)

            case let .paragraph(text):
                Text(text)
                    .font(useSerif ? .system(size: baseSize, design: .serif) : .system(size: baseSize, design: .default))
                    .lineSpacing(AppTypography.defaultLineSpacing)
                    .foregroundStyle(AppColor.textPrimary(for: theme))
                    .padding(.vertical, AppSpacing.xxs)
                    .frame(maxWidth: .infinity, alignment: .leading)

            case let .blockquote(text):
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(AppColor.accent(for: theme).opacity(0.6))
                        .frame(width: 4)
                        .padding(.trailing, AppSpacing.md)

                    Text(text)
                        .font(useSerif ? .system(size: baseSize, design: .serif).italic() : .system(size: baseSize, design: .default).italic())
                        .foregroundStyle(AppColor.textSecondary(for: theme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, AppSpacing.sm)
                .padding(.leading, AppSpacing.xs)

            case let .listItem(text):
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Text("•")
                        .font(.system(size: baseSize, weight: .bold))
                        .foregroundStyle(AppColor.accent(for: theme))

                    Text(text)
                        .font(useSerif ? .system(size: baseSize, design: .serif) : .system(size: baseSize, design: .default))
                        .foregroundStyle(AppColor.textPrimary(for: theme))
                }
                .padding(.vertical, AppSpacing.xxs)
                .frame(maxWidth: .infinity, alignment: .leading)

            case let .codeBlock(code, _):
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(code)
                        .font(.system(size: baseSize * 0.9, design: .monospaced))
                        .foregroundStyle(theme == .dark ? Color.green : AppColor.textPrimary(for: theme))
                        .padding(AppSpacing.md)
                }
                .background(AppColor.surfaceSecondary(for: theme))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.xs))
                .padding(.vertical, AppSpacing.sm)
            }
        }
        .padding(.horizontal, AppSpacing.xs)
        .background(highlightBgColor)
        .contentShape(Rectangle())
        .contextMenu {
            if let active = highlight {
                Button(role: .destructive) {
                    deleteHighlight(active)
                } label: {
                    Label("Eliminar destacado", systemImage: "trash")
                }
            } else {
                Menu("Destacar") {
                    ForEach(HighlightCategory.allCases, id: \.self) { cat in
                        Button {
                            createHighlight(category: cat, blockIndex: block.index, text: block.rawText)
                        } label: {
                            Label(cat.rawValue, systemImage: "circle.fill")
                        }
                    }
                }
                
                Button {
                    selectedBlockIndex = block.index
                    noteBody = ""
                    noteTags = ""
                    pendingCategory = nil
                    showNoteEditor = true
                } label: {
                    Label("Añadir nota", systemImage: "note.text.badge.plus")
                }
            }
            
            Divider()
            
            Menu("Lectoria AI") {
                Button(action: { triggerAIAction("explain", text: block.rawText, blockIndex: block.index) }) {
                    Label("Explicar con IA", systemImage: "sparkles")
                }
                Button(action: { triggerAIAction("simplify", text: block.rawText, blockIndex: block.index) }) {
                    Label("Simplificar", systemImage: "text.alignleft")
                }
                Button(action: { triggerAIAction("translate", text: block.rawText, blockIndex: block.index) }) {
                    Label("Traducir", systemImage: "translate")
                }
                Button(action: { triggerAIAction("generateQuestions", text: block.rawText, blockIndex: block.index) }) {
                    Label("Crear pregunta", systemImage: "questionmark.circle")
                }
            }
        }
    }

    // MARK: - Table of Contents & Bookmarks Sheet

    private func tocSheet(theme: AppTheme) -> some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                            Text("Este documento no tiene secciones.")
                                .font(AppTypography.callout)
                                .foregroundStyle(AppColor.textSecondary(for: theme))
                            Spacer()
                        }
                    } else {
                        List(tocItems) { item in
                            Button {
                                if !item.locationData.isEmpty,
                                   let location = try? JSONDecoder().decode(TextLocation.self, from: item.locationData) {
                                    targetLocation = location
                                    showTOC = false
                                }
                            } label: {
                                HStack {
                                    Text(item.title)
                                        .font(AppTypography.body)
                                        .foregroundStyle(AppColor.textPrimary(for: theme))
                                        .padding(.leading, CGFloat(item.level * 16))
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
                                   let location = try? JSONDecoder().decode(TextLocation.self, from: data) {
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

            // Selector de Fuente
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Tipografía")
                    .font(AppTypography.footnote)
                    .foregroundStyle(AppColor.textSecondary(for: theme))

                HStack(spacing: AppSpacing.md) {
                    Button {
                        useSerif = true
                    } label: {
                        Text("Serif (New York)")
                            .font(.system(.callout, design: .serif))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.sm)
                            .background(useSerif ? AppColor.accent(for: theme) : AppColor.surfaceSecondary(for: theme))
                            .foregroundStyle(useSerif ? .white : AppColor.textPrimary(for: theme))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                    }

                    Button {
                        useSerif = false
                    } label: {
                        Text("Sans-Serif (Sistema)")
                            .font(.system(.callout, design: .default))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.sm)
                            .background(!useSerif ? AppColor.accent(for: theme) : AppColor.surfaceSecondary(for: theme))
                            .foregroundStyle(!useSerif ? .white : AppColor.textPrimary(for: theme))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)

            // Selector de Tamaño de Fuente
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Tamaño de letra")
                    .font(AppTypography.footnote)
                    .foregroundStyle(AppColor.textSecondary(for: theme))

                HStack {
                    Button {
                        if fontSizeMultiplier > 0.6 { fontSizeMultiplier -= 0.1 }
                    } label: {
                        Image(systemName: "minus")
                            .font(.title3)
                            .padding()
                            .foregroundStyle(AppColor.textPrimary(for: theme))
                    }

                    Spacer()

                    Text(String(format: "%.0f%%", fontSizeMultiplier * 100))
                        .font(AppTypography.bodyBold)
                        .foregroundStyle(AppColor.textPrimary(for: theme))

                    Spacer()

                    Button {
                        if fontSizeMultiplier < 2.0 { fontSizeMultiplier += 0.1 }
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3)
                            .padding()
                            .foregroundStyle(AppColor.textPrimary(for: theme))
                    }
                }
                .background(AppColor.surfaceSecondary(for: theme))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
            }
            .padding(.horizontal, AppSpacing.lg)

            Spacer()
        }
        .padding(.bottom, AppSpacing.xxl)
        .background(AppColor.surface(for: theme))
        .presentationDetents([.height(380)])
    }

    // MARK: - Search Sheet

    private func searchSheet(theme: AppTheme) -> some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                               let location = try? JSONDecoder().decode(TextLocation.self, from: result.locationData) {
                                targetLocation = location
                                showSearch = false
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                Text(result.chapterTitle ?? "Párrafo")
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
            .navigationTitle("Buscar en el documento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { showSearch = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Lifecycle & Progress Operations

    private func loadText() async {
        isLoading = true
        loadingError = nil

        do {
            // 1. Cargar el último progreso guardado de la base de datos
            if let savedProgress = try? await dependencies.readingProgressRepository.fetchProgress(forPublication: record.id),
               let data = savedProgress.locatorJSON.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(TextLocation.self, from: data) {
                self.initialLocation = decoded
                self.currentLocation = decoded
            }

            // 2. Abrir la publicación con el adaptador
            try await adapter.open(publication: record)

            // 3. Obtener el índice (TOC)
            self.tocItems = (try? await adapter.tableOfContents()) ?? []

            // 4. Cargar marcadores locales
            await loadBookmarks()

            // 5. Cargar destacados locales
            await loadHighlights()

            self.isLoading = false

            // 6. Navegar a la posición inicial guardada con un pequeño delay de rendering
            if let initial = initialLocation {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    targetLocation = initial
                }
            }
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

    private func activeHighlight(for index: Int) -> Highlight? {
        highlights.first { highlight in
            if let data = highlight.anchor.data(using: .utf8),
               let location = try? JSONDecoder().decode(TextLocation.self, from: data) {
                return location.blockIndex == index
            }
            return false
        }
    }

    private func categoryColorName(_ name: String?) -> Color {
        guard let name = name?.lowercased() else { return .clear }
        switch name {
        case "idea principal", "blue", "mainidea":
            return .blue.opacity(0.2)
        case "duda", "purple", "question":
            return .purple.opacity(0.2)
        case "evidencia", "green", "evidence":
            return .green.opacity(0.2)
        case "acción", "accion", "orange", "coral", "action":
            return .orange.opacity(0.2)
        case "cita", "pink", "quote":
            return .pink.opacity(0.2)
        default:
            return .clear
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

    private func createHighlight(category: HighlightCategory, blockIndex: Int, text: String, customNoteBody: String? = nil) {
        let colorToken = categoryColorToken(category)
        let total = adapter.blocks.count
        let pct = total > 1 ? Double(blockIndex) / Double(total - 1) : 0.0
        let loc = TextLocation(blockIndex: blockIndex, characterOffset: 0, percentage: pct)
        let anchorData = (try? JSONEncoder().encode(loc)) ?? Data()
        let anchorStr = String(data: anchorData, encoding: .utf8) ?? ""
        
        let highlight = Highlight(
            publicationID: record.id,
            anchor: anchorStr,
            selectedText: text,
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
            
            await loadHighlights()
        }
    }
    
    private func triggerAIAction(_ actionName: String, text: String, blockIndex: Int) {
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
                    self.textToProcess = text
                    self.selectedBlockIndex = blockIndex
                    self.pendingAIAction = actionName
                    self.showConsent = true
                }
            } else {
                await MainActor.run {
                    self.textToProcess = text
                    self.selectedBlockIndex = blockIndex
                    self.pendingAIAction = actionName
                    self.showAIResponse = true
                }
            }
        }
    }

    private func deleteHighlight(_ highlight: Highlight) {
        Task {
            // Eliminar destacado de la base de datos
            try? await dependencies.highlightRepository.delete(id: highlight.id)
            
            // Eliminar notas asociadas
            if let notes = try? await dependencies.noteRepository.fetch(forPublication: record.id) {
                for note in notes {
                    if note.highlightID == highlight.id {
                        try? await dependencies.noteRepository.delete(id: note.id)
                    }
                }
            }
            
            await loadHighlights()
        }
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
                        if let index = selectedBlockIndex, index < adapter.blocks.count {
                            let block = adapter.blocks[index]
                            createHighlight(category: selectedCat, blockIndex: index, text: block.rawText, customNoteBody: noteBody)
                        }
                        showNoteEditor = false
                    }
                    .disabled(noteBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveReadingProgress(location: TextLocation) {
        Task {
            let total = adapter.blocks.count
            let percentage = total > 1 ? Double(location.blockIndex) / Double(total - 1) : 0.0
            let chapterTitle = "Párrafo \(location.blockIndex + 1)"
            let locatorJSON = (try? String(data: JSONEncoder().encode(location), encoding: .utf8)) ?? ""

            let progress = ReadingProgress(
                publicationID: record.id,
                locatorJSON: locatorJSON,
                percentage: percentage,
                pageNumber: location.blockIndex + 1,
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
               let location = try? JSONDecoder().decode(TextLocation.self, from: data) {
                return location.blockIndex == current.blockIndex
            }
            return false
        }
    }

    private func toggleBookmark() {
        guard let current = currentLocation else { return }

        Task {
            if isCurrentPageBookmarked {
                let bookmarkToDelete = bookmarks.first { bookmark in
                    if let data = bookmark.anchor.data(using: .utf8),
                       let location = try? JSONDecoder().decode(TextLocation.self, from: data) {
                        return location.blockIndex == current.blockIndex
                    }
                    return false
                }

                if let bookmark = bookmarkToDelete {
                    try? await dependencies.bookmarkRepository.delete(id: bookmark.id)
                }
            } else {
                let label = "Párrafo \(current.blockIndex + 1)"
                let anchorData = (try? JSONEncoder().encode(current)) ?? Data()
                let anchorStr = String(data: anchorData, encoding: .utf8) ?? ""

                let bookmark = Bookmark(
                    publicationID: record.id,
                    anchor: anchorStr,
                    title: label
                )

                try? await dependencies.bookmarkRepository.save(bookmark)
            }

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

    private func updateCurrentLocation() {
        guard !adapter.blocks.isEmpty else { return }

        if let firstVisible = visibleIndices.min() {
            let percentage = Double(firstVisible) / Double(max(1, adapter.blocks.count - 1))
            self.currentLocation = TextLocation(
                blockIndex: firstVisible,
                characterOffset: 0,
                percentage: percentage
            )
        }
    }

    private var safeAreaTop: CGFloat {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        return windowScene?.windows.first?.safeAreaInsets.top ?? 20
    }
}
