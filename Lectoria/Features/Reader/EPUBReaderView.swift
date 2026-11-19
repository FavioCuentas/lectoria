import SwiftUI
import ReadiumShared
import ReadiumNavigator
import Translation

// MARK: - EPUBReaderView

/// Pantalla del lector de libros EPUB.
///
/// Integra el adaptador Readium con el Design System de Lectoria,
/// ofreciendo una experiencia inmersiva con controles de formato
/// (tamaño de fuente, scroll vs paginación, temas claro/oscuro/sepia),
/// índice interactivo y autoguardado de progreso.
struct EPUBReaderView: View {
    let record: PublicationRecord
    
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    // Estado del ciclo de vida del lector
    @State private var adapter = EPUBReaderAdapter()
    @State private var isLoading = true
    @State private var loadingError: String? = nil
    @State private var sessionCoordinator: ReadingSessionCoordinator?
    
    // Ubicación de lectura y navegación
    @State private var initialLocation: EPUBLocation? = nil
    @State private var currentLocation: EPUBLocation? = nil
    @State private var targetLocation: EPUBLocation? = nil
    @State private var tocItems: [TOCItem] = []

    // Selección, Destacados y Anotaciones
    @State private var highlights: [Highlight] = []
    @State private var selectedText = ""
    @State private var hasSelection = false
    @State private var selectedLocator: Locator? = nil

    // Editor de Notas y Paywall
    @State private var showNoteEditor = false
    @State private var showPaywall = false
    @State private var showConsent = false
    @State private var pendingAIAction: String? = nil
    @State private var noteBody = ""
    @State private var noteTags = ""
    @State private var pendingCategory: HighlightCategory? = nil
    @State private var lastAIAction = ""
    @State private var translationConfig: TranslationSession.Configuration?
    @State private var textToTranslate = ""
    
    // Respuesta inline (globo flotante)
    @State private var showInlineBubble = false
    @State private var inlineBubbleTitle = ""
    @State private var inlineBubbleText = ""
    @State private var isLoadingInline = false

    // Controles de interfaz de usuario
    @State private var showUI = true
    @State private var showTOC = false
    @State private var showSettings = false
    @State private var showGoToPageDialog = false
    @State private var goToPageText = ""
    @State private var lastJumpOriginLocation: EPUBLocation? = nil

    // Búsqueda de texto
    @State private var navigatorReference: EPUBNavigatorViewController? = nil
    @State private var showSearch = false
    @State private var searchQuery = ""
    @State private var searchMatches: [EPUBSearchMatch] = []
    @State private var isSearching = false
    /// Búsqueda en curso; se cancela al lanzar otra o al limpiar.
    @State private var searchTask: Task<Void, Never>? = nil
    /// Coincidencia activa (sombreada en naranja y mostrada en la barra "N de M").
    @State private var activeMatchIndex: Int? = nil
    /// Coincidencia a la que saltar cuando termine de cerrarse la hoja de búsqueda.
    @State private var pendingSearchJump: Int? = nil

    // Preferencias del usuario (persistidas o inicializadas por defecto)
    @State private var fontSize: Double = 1.0
    @State private var isScrollMode = false

    /// Búsqueda con la que se abrió el lector desde la búsqueda global (se aplica una vez).
    @State private var pendingInitialSearch: InitialSearch?

    init(record: PublicationRecord, initialLocation: EPUBLocation? = nil, initialSearch: InitialSearch? = nil) {
        self.record = record
        self._initialLocation = State(initialValue: initialLocation)
        self._pendingInitialSearch = State(initialValue: initialSearch)
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
            } else if let publication = adapter.publication {
                // Wrapper del visor de Readium
                EPUBNavigatorWrapper(
                    publication: publication,
                    initialLocation: initialLocation,
                    currentLocation: $currentLocation,
                    preferences: epubPreferences,
                    selectedText: $selectedText,
                    hasSelection: $hasSelection,
                    selectedLocator: $selectedLocator,
                    highlights: highlights,
                    onTap: { _ in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showUI.toggle()
                        }
                    },
                    targetLocation: targetLocation,
                    navigatorBinding: $navigatorReference
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
            
            // Barra de navegación entre coincidencias de búsqueda
            if let activeIndex = activeMatchIndex, !searchMatches.isEmpty, !showSearch {
                VStack {
                    ReaderSearchNavigatorBar(
                        query: searchQuery,
                        activeIndex: activeIndex,
                        total: searchMatches.count,
                        theme: appTheme,
                        onPrevious: { selectSearchMatch(at: (activeIndex - 1 + searchMatches.count) % searchMatches.count) },
                        onNext: { selectSearchMatch(at: (activeIndex + 1) % searchMatches.count) },
                        onShowList: { showSearch = true },
                        onClose: { clearSearch() }
                    )
                    .padding(.top, showUI ? safeAreaTop + 56 : AppSpacing.md)
                    Spacer()
                }
                .ignoresSafeArea(edges: .top)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Globo flotante de respuesta inline
            if showInlineBubble {
                inlineResponseBubble(theme: appTheme)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(!showUI)
        .task {
            await loadBook()
            await loadHighlights()
        }
        .onChange(of: navigatorReference) { _, navigator in
            if navigator != nil { applyInitialSearchIfNeeded() }
        }
        .onChange(of: currentLocation) { _, newValue in
            if let newValue {
                saveReadingProgress(location: newValue)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            sessionCoordinator?.handleScenePhaseChange(newPhase)
        }
        .onDisappear {
            sessionCoordinator?.endSession()
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
            Text(String(localized: "Abriendo libro…", comment: "Reader: loading book"))
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
                Task { await loadBook() }
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
                    
                    Spacer()
                    
                    Text(record.title)
                        .font(AppTypography.bodyBold)
                        .lineLimit(1)
                        .foregroundStyle(AppColor.textPrimary(for: theme))
                    
                    Spacer()
                    
                    // Botón de Búsqueda de Texto
                    Button {
                        showSearch.toggle()
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.title3)
                            .padding(AppSpacing.md)
                            .foregroundStyle(AppColor.textPrimary(for: theme))
                    }
                    .accessibilityLabel("Buscar en el libro")
                    
                    // Botón de Formato / Preferencias
                    Button {
                        showSettings.toggle()
                    } label: {
                        Image(systemName: "textformat")
                            .font(.title3)
                            .padding(AppSpacing.md)
                            .foregroundStyle(AppColor.textPrimary(for: theme))
                    }
                    
                    // Botón del Índice / TOC
                    Button {
                        showTOC.toggle()
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.title3)
                            .padding(AppSpacing.md)
                            .foregroundStyle(AppColor.textPrimary(for: theme))
                    }
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
                // Botón flotante para volver a la ubicación previa tras un salto
                if let origin = lastJumpOriginLocation, origin != currentLocation {
                    Button {
                        lastJumpOriginLocation = nil
                        targetLocation = origin
                    } label: {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .font(.subheadline)
                            Text("Volver a la ubicación anterior")
                                .font(AppTypography.captionBold)
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.xs)
                        .background(AppColor.accent(for: theme))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .shadow(color: AppShadow.medium(for: theme).color,
                                radius: AppShadow.medium(for: theme).radius,
                                x: AppShadow.medium(for: theme).x,
                                y: AppShadow.medium(for: theme).y)
                    }
                    .padding(.bottom, AppSpacing.xxs)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Barra Inferior (Progreso)
                VStack(spacing: AppSpacing.sm) {
                    let progressPercent = currentLocation?.locator.locations.totalProgression ?? 0.0
                    
                    HStack {
                        Button {
                            goToPageText = String(format: "%.0f%%", progressPercent * 100)
                            showGoToPageDialog = true
                        } label: {
                            HStack(spacing: AppSpacing.xxs) {
                                Text(currentLocation?.locator.title ?? "Capítulo")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColor.textSecondary(for: theme))
                                    .lineLimit(1)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(AppColor.textTertiary(for: theme))
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Ir a página o porcentaje")
                        
                        Spacer()
                        
                        Button {
                            goToPageText = String(format: "%.0f%%", progressPercent * 100)
                            showGoToPageDialog = true
                        } label: {
                            Text(String(format: "%.0f%%", progressPercent * 100))
                                .font(AppTypography.captionBold)
                                .foregroundStyle(AppColor.accent(for: theme))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Ir a página o porcentaje")
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    
                    ProgressView(value: progressPercent, total: 1.0)
                        .tint(AppColor.accent(for: theme))
                        .padding(.horizontal, AppSpacing.lg)
                }
                .padding(.top, AppSpacing.md)
                .padding(.bottom, safeAreaBottom + AppSpacing.xs)
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
        .translationTask(translationConfig) { session in
            let text = textToTranslate
            guard !text.isEmpty else { return }
            do {
                let translated = try await LocalTranslation.translate(text, using: .init(session: session))
                withAnimation(.spring(response: 0.3)) {
                    inlineBubbleText = translated
                    isLoadingInline = false
                }
            } catch {
                withAnimation(.spring(response: 0.3)) {
                    inlineBubbleText = LocalTranslation.errorMessage(error)
                    isLoadingInline = false
                }
            }
        }
        .sheet(isPresented: $showSearch, onDismiss: {
            // Navegar solo cuando la hoja ya se cerró para que el salto no se pierda.
            if let index = pendingSearchJump {
                pendingSearchJump = nil
                selectSearchMatch(at: index)
            }
        }) {
            searchSheet(theme: theme)
        }
        .sheet(isPresented: $showSettings) {
            settingsSheet(theme: theme)
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
                    executeInlineAI(action: pending)
                }
            }
        }
        .alert("Ir a página", isPresented: $showGoToPageDialog) {
            TextField("Número de página o %", text: $goToPageText)
                .keyboardType(.numberPad)
            Button("Ir") {
                performEPUBJump()
            }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Introduce un número de página o un porcentaje de avance.")
        }
    }

    // MARK: - Table of Contents Sheet

    // MARK: - Búsqueda

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
                        .submitLabel(.search)
                        .onSubmit { performSearch() }

                    if !searchQuery.isEmpty {
                        Button {
                            clearSearch()
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
                } else if searchMatches.isEmpty {
                    VStack {
                        Spacer()
                        Text(searchQuery.isEmpty ? "Escribe una palabra y pulsa Buscar." : "No se encontraron resultados.")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColor.textSecondary(for: theme))
                        Spacer()
                    }
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(searchSummary)
                            .font(AppTypography.footnote.weight(.semibold))
                            .foregroundStyle(AppColor.textSecondary(for: theme))
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.vertical, AppSpacing.xs)

                        List(searchMatches) { match in
                            Button {
                                activeMatchIndex = match.id
                                pendingSearchJump = match.id
                                showSearch = false
                            } label: {
                                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                    Text(match.chapterTitle)
                                        .font(AppTypography.footnote.weight(.semibold))
                                        .foregroundStyle(AppColor.accent(for: theme))
                                        .lineLimit(1)

                                    Text(match.snippet)
                                        .font(AppTypography.body)
                                        .foregroundStyle(AppColor.textPrimary(for: theme))
                                        .lineLimit(2)
                                }
                            }
                            .listRowBackground(
                                match.id == activeMatchIndex
                                    ? AppColor.accent(for: theme).opacity(0.12)
                                    : AppColor.surface(for: theme)
                            )
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .background(AppColor.background(for: theme))
            .navigationTitle("Buscar en el libro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { showSearch = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func performSearch() {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let publication = adapter.publication else { return }

        // Cancelar una búsqueda anterior aún en curso: la nueva es la dueña del indicador.
        searchTask?.cancel()
        isSearching = true
        activeMatchIndex = nil
        searchMatches.removeAll()
        if let navigator = navigatorReference {
            EPUBTextSearch.clearHighlights(on: navigator)
        }
        let query = searchQuery

        searchTask = Task { @MainActor in
            let matches = await EPUBTextSearch.search(query, in: publication)
            // Si se lanzó otra búsqueda o se limpió mientras tanto, descartar estos resultados.
            guard !Task.isCancelled else { return }
            searchMatches = matches
            isSearching = false
            if let navigator = navigatorReference {
                EPUBTextSearch.applyHighlights(matches, activeIndex: nil, on: navigator)
            }
        }
    }

    /// Al abrir desde la búsqueda global: busca la consulta y salta a la primera coincidencia
    /// del capítulo del resultado (o a la primera del libro si ahí ya no está).
    private func applyInitialSearchIfNeeded() {
        guard let initial = pendingInitialSearch, let publication = adapter.publication else { return }
        pendingInitialSearch = nil
        searchQuery = initial.query
        isSearching = true
        let scope = initial.scope.map(InitialSearchKey.normalizedHref)
        searchTask?.cancel()
        searchTask = Task { @MainActor in
            // Dejar que el navegador cargue el primer capítulo antes de sombrear y saltar.
            try? await Task.sleep(for: .milliseconds(400))
            let matches = await EPUBTextSearch.search(initial.query, in: publication)
            guard !Task.isCancelled else { return }
            searchMatches = matches
            isSearching = false
            let index = InitialSearchResolver.firstMatchIndex(in: matches, scope: scope, scopeOf: { match in
                let key = InitialSearchKey.normalizedHref(match.chapterKey)
                // El índice puede guardar la ruta completa y Readium una relativa, o al revés.
                if let scope, key != scope, key.hasSuffix("/" + scope) || scope.hasSuffix("/" + key) { return scope }
                return key
            })
            if let index {
                selectSearchMatch(at: index)
            } else {
                showSearch = true
            }
        }
    }

    /// Activa la coincidencia `index`: la sombrea en naranja y navega a su posición.
    private func selectSearchMatch(at index: Int) {
        guard searchMatches.indices.contains(index), let navigator = navigatorReference else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            activeMatchIndex = index
        }
        EPUBTextSearch.applyHighlights(searchMatches, activeIndex: index, on: navigator)
        let locator = searchMatches[index].locator
        Task { @MainActor in
            _ = await navigator.go(to: locator, options: .animated)
        }
    }

    /// Limpia la búsqueda, sus resultados y el sombreado del libro.
    private func clearSearch() {
        searchTask?.cancel()
        searchTask = nil
        searchQuery = ""
        searchMatches.removeAll()
        pendingSearchJump = nil
        isSearching = false
        withAnimation(.easeInOut(duration: 0.2)) {
            activeMatchIndex = nil
        }
        if let navigator = navigatorReference {
            EPUBTextSearch.clearHighlights(on: navigator)
        }
    }

    /// Texto de resumen: "12 coincidencias en 3 capítulos".
    private var searchSummary: String {
        let total = searchMatches.count
        let chapters = EPUBTextSearch.chapterCount(of: searchMatches)
        let matchesText = total == 1 ? "1 coincidencia" : "\(total) coincidencias"
        let chaptersText = chapters == 1 ? "1 capítulo" : "\(chapters) capítulos"
        let capped = total >= EPUBTextSearch.maxMatches ? " (mostrando las primeras \(EPUBTextSearch.maxMatches))" : ""
        return "\(matchesText) en \(chaptersText)\(capped)"
    }

    private func tocSheet(theme: AppTheme) -> some View {
        NavigationStack {
            List(tocItems) { item in
                let data = item.locationData
                Button {
                    if !data.isEmpty,
                       let location = try? JSONDecoder().decode(EPUBLocation.self, from: data) {
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
            .background(AppColor.background(for: theme))
            .scrollContentBackground(.hidden)
            .navigationTitle("Índice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { showTOC = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
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
                Text("Tema")
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

            // Selector de Tamaño de Fuente
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Tamaño de letra")
                    .font(AppTypography.footnote)
                    .foregroundStyle(AppColor.textSecondary(for: theme))
                
                HStack {
                    Button {
                        if fontSize > 0.6 { fontSize -= 0.1 }
                    } label: {
                        Image(systemName: "minus")
                            .font(.title3)
                            .padding()
                            .foregroundStyle(AppColor.textPrimary(for: theme))
                    }
                    
                    Spacer()
                    
                    Text(String(format: "%.0f%%", fontSize * 100))
                        .font(AppTypography.bodyBold)
                        .foregroundStyle(AppColor.textPrimary(for: theme))
                    
                    Spacer()
                    
                    Button {
                        if fontSize < 2.0 { fontSize += 0.1 }
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

            // Dirección de Lectura (Scroll vs Páginas)
            Toggle(isOn: $isScrollMode) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("Desplazamiento continuo")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColor.textPrimary(for: theme))
                    Text("Desplazar verticalmente en lugar de paginar")
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
        .presentationDetents([.height(350)])
    }

    // MARK: - Book Lifecycle

    private func loadBook() async {
        isLoading = true
        loadingError = nil
        
        do {
            // 1. Cargar el último progreso guardado de base de datos
            // Una ubicación pedida al abrir (nota, destacado) tiene prioridad sobre el progreso.
            if let requested = self.initialLocation {
                self.currentLocation = requested
            } else if let savedProgress = try? await dependencies.readingProgressRepository.fetchProgress(forPublication: record.id),
               let data = savedProgress.locatorJSON.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(EPUBLocation.self, from: data) {
                self.initialLocation = decoded
                self.currentLocation = decoded
            }
            
            // 2. Abrir la publicación con el adaptador de Readium
            try await adapter.open(publication: record)
            
            // Registrar fecha de apertura
            await PublicationRecordUpdates.markOpened(record.id, repository: dependencies.publicationRepository)
            
            // 3. Extraer la Tabla de Contenidos
            self.tocItems = (try? await adapter.tableOfContents()) ?? []
            
            self.isLoading = false

            if sessionCoordinator == nil {
                let coordinator = ReadingSessionCoordinator(
                    publicationID: record.id,
                    format: record.publicationType.analyticsFormat,
                    analyticsService: dependencies.analyticsService,
                    readingSessionRepository: dependencies.readingSessionRepository,
                    progressProvider: { currentLocation?.locator.locations.totalProgression }
                )
                coordinator.startSession()
                self.sessionCoordinator = coordinator
            }
        } catch {
            self.loadingError = error.localizedDescription
            self.isLoading = false
        }
    }

    private func saveReadingProgress(location: EPUBLocation) {
        Task {
            let percentage = location.locator.locations.totalProgression ?? 0.0
            let chapterTitle = location.locator.title ?? location.locator.href.string
            let locatorJSON = (try? String(data: JSONEncoder().encode(location), encoding: .utf8)) ?? ""
            
            let progress = ReadingProgress(
                publicationID: record.id,
                locatorJSON: locatorJSON,
                percentage: percentage,
                chapterTitle: chapterTitle,
                deviceID: DeviceIdentity.current,
                version: 1
            )
            try? await dependencies.readingProgressRepository.saveProgress(progress)
        }
    }

    // MARK: - Helpers

    private var epubPreferences: EPUBPreferences {
        let readiumTheme: ReadiumNavigator.Theme
        switch themeManager.currentTheme {
        case .light: readiumTheme = .light
        case .dark: readiumTheme = .dark
        case .sepia: readiumTheme = .sepia
        }
        
        return EPUBPreferences(
            fontSize: fontSize,
            scroll: isScrollMode,
            theme: readiumTheme
        )
    }

    private var safeAreaTop: CGFloat {
        let topInset = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .safeAreaInsets.top ?? 24
        return max(topInset, 24)
    }

    private var safeAreaBottom: CGFloat {
        let bottomInset = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .safeAreaInsets.bottom ?? 0
        return max(bottomInset, 16)
    }

    private func performEPUBJump() {
        let raw = goToPageText.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "%", with: "")
        guard let val = Double(raw) else { return }
        let clamped = max(0.0, min(100.0, val)) / 100.0
        if let currentLoc = currentLocation {
            lastJumpOriginLocation = currentLocation
            var loc = currentLoc.locator
            // Actualizar progresión si la estructura de Locator lo permite
            loc = Locator(
                href: loc.href,
                mediaType: loc.mediaType,
                title: loc.title,
                locations: Locator.Locations(
                    fragments: loc.locations.fragments,
                    progression: loc.locations.progression,
                    totalProgression: clamped,
                    position: loc.locations.position
                ),
                text: loc.text
            )
            targetLocation = EPUBLocation(locator: loc)
        }
    }

    // MARK: - Annotation Helpers
    
    private func loadHighlights() async {
        if let list = try? await dependencies.highlightRepository.fetch(forPublication: record.id) {
            await MainActor.run {
                self.highlights = list
            }
        }
    }

    /// Colores vibrantes y opacos para los botones circulares de la barra flotante.
    private func categoryColor(_ category: HighlightCategory) -> SwiftUI.Color {
        switch category {
        case .mainIdea: return SwiftUI.Color(red: 0.30, green: 0.55, blue: 0.80)   // Azul
        case .question: return SwiftUI.Color(red: 0.55, green: 0.38, blue: 0.75)   // Púrpura
        case .evidence: return SwiftUI.Color(red: 0.25, green: 0.65, blue: 0.45)   // Verde
        case .action:   return SwiftUI.Color(red: 0.85, green: 0.47, blue: 0.34)   // Coral
        case .quote:    return SwiftUI.Color(red: 0.80, green: 0.42, blue: 0.55)   // Rosa
        case .dictionary:  return SwiftUI.Color(red: 0.18, green: 0.60, blue: 0.60) // Turquesa
        case .translation: return SwiftUI.Color(red: 0.36, green: 0.36, blue: 0.75) // Índigo
        case .ai:          return SwiftUI.Color(red: 0.12, green: 0.53, blue: 0.82) // Celeste
        }
    }
    
    private func categoryColorToken(_ category: HighlightCategory) -> String {
        switch category {
        case .mainIdea: return "mainIdea"
        case .question: return "question"
        case .evidence: return "evidence"
        case .action: return "action"
        case .quote: return "quote"
        case .dictionary: return "dictionary"
        case .translation: return "translation"
        case .ai: return "ai"
        }
    }

    private func createHighlight(category: HighlightCategory, customNoteBody: String? = nil) {
        guard let locator = selectedLocator else { return }
        
        let colorToken = categoryColorToken(category)
        let anchorStr = (try? locator.jsonString()) ?? ""
        
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
                    body: customNoteBody,
                    tags: tagsArray
                )
                try? await dependencies.noteRepository.save(note)
            }
            
            await loadHighlights()
            await MainActor.run {
                // Despejar selección
                self.selectedText = ""
                self.hasSelection = false
                self.selectedLocator = nil
            }
        }
    }

    private func triggerAIAction(_ actionName: String) {
        Task {
            // La traducción local es una función Premium con su propio permiso
            // y no consume el cupo de IA ni requiere consentimiento de IA generativa.
            if actionName.hasPrefix("translate_") {
                let access = await dependencies.entitlementService.canAccess(.useLocalTranslation)
                guard access == .allowed else {
                    await MainActor.run {
                        self.showPaywall = true
                    }
                    return
                }
                await MainActor.run {
                    executeInlineAI(action: actionName)
                }
                return
            }

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
        lastAIAction = action
        
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
        
        // Traducción local real con el framework Translation: se dispara vía .translationTask,
        // que debe estar vinculado a la vista (puede presentar la descarga del idioma).
        if action.hasPrefix("translate_") {
            let langCode = String(action.dropFirst("translate_".count))
            textToTranslate = textToProcess
            let target = LocalTranslation.targetLanguage(for: langCode)
            if var config = translationConfig, config.target == target {
                config.invalidate()
                translationConfig = config
            } else {
                translationConfig = TranslationSession.Configuration(source: nil, target: target)
            }
            return
        }

        Task {
            let token = dependencies.authService.sessionToken
            do {
                let result: String
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
                    ForEach(HighlightCategory.userSelectableCases, id: \.self) { category in
                        Button {
                            createHighlight(category: category)
                        } label: {
                            Circle()
                                .fill(categoryColor(category))
                                .frame(width: circleSize, height: circleSize)
                                .overlay(
                                    Circle()
                                        .stroke(SwiftUI.Color.white, lineWidth: 2)
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
                        hasSelection = false
                        selectedText = ""
                        selectedLocator = nil
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
                                .font((isPad ? AppTypography.bodyBold : AppTypography.caption.weight(.semibold)))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, isPad ? AppSpacing.md : AppSpacing.sm)
                        .padding(.vertical, isPad ? AppSpacing.xs : AppSpacing.xxs)
                        .background(
                            LinearGradient(
                                colors: [
                                    SwiftUI.Color(red: 0.55, green: 0.38, blue: 0.85),
                                    SwiftUI.Color(red: 0.85, green: 0.47, blue: 0.34)
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

    /// Busca la definición de la palabra seleccionada usando IA inline.
    private func showDictionary(for term: String) {
        let word = term.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines).first ?? term
        guard !word.isEmpty else { return }
        // Pasar por triggerAIAction para respetar límites del plan y consentimiento de IA,
        // igual que Traducir y las demás acciones de IA.
        triggerAIAction("define")
    }

    /// Globo flotante que muestra la respuesta de Diccionario, Traducción o IA inline.
    private func inlineResponseBubble(theme: AppTheme) -> some View {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        
        return VStack {
            Spacer()
            
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
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
                
                ExpandableSourceText(
                    text: selectedText,
                    theme: theme,
                    font: isPad ? AppTypography.body : AppTypography.caption
                )
                
                Divider()
                
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
                        Text(AttributedString.inlineMarkdown(inlineBubbleText))
                            .font(isPad ? AppTypography.body : AppTypography.body) // Or custom size if needed
                            .foregroundStyle(AppColor.textPrimary(for: theme))
                            .lineSpacing(isPad ? 6 : 4)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: isPad ? 350 : 200)
                    
                    Button {
                        let category: HighlightCategory
                        if lastAIAction.hasPrefix("translate") {
                            category = .translation
                        } else if lastAIAction == "define" {
                            category = .dictionary
                        } else {
                            category = .ai
                        }
                        createHighlight(category: category, customNoteBody: inlineBubbleText)
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

    private func noteEditorSheet(theme: AppTheme) -> some View {
        NavigationStack {
            VStack(spacing: AppSpacing.md) {
                Picker("Categoría", selection: Binding(
                    get: { pendingCategory ?? .mainIdea },
                    set: { pendingCategory = $0 }
                )) {
                    ForEach(HighlightCategory.userSelectableCases, id: \.self) { cat in
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
}
