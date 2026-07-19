import SwiftUI
import ReadiumShared
import ReadiumNavigator

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

    // Estado del ciclo de vida del lector
    @State private var adapter = EPUBReaderAdapter()
    @State private var isLoading = true
    @State private var loadingError: String? = nil
    
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
    
    // Respuesta inline (globo flotante)
    @State private var showInlineBubble = false
    @State private var inlineBubbleTitle = ""
    @State private var inlineBubbleText = ""
    @State private var isLoadingInline = false

    // Controles de interfaz de usuario
    @State private var showUI = true
    @State private var showTOC = false
    @State private var showSettings = false

    // Preferencias del usuario (persistidas o inicializadas por defecto)
    @State private var fontSize: Double = 1.0
    @State private var isScrollMode = false

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
                // Barra Inferior (Progreso)
                VStack(spacing: AppSpacing.sm) {
                    let progressPercent = currentLocation?.locator.locations.totalProgression ?? 0.0
                    
                    HStack {
                        Text(currentLocation?.locator.title ?? "Capítulo")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColor.textSecondary(for: theme))
                            .lineLimit(1)
                        
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
    }

    // MARK: - Table of Contents Sheet

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
            if let savedProgress = try? await dependencies.readingProgressRepository.fetchProgress(forPublication: record.id),
               let data = savedProgress.locatorJSON.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(EPUBLocation.self, from: data) {
                self.initialLocation = decoded
                self.currentLocation = decoded
            }
            
            // 2. Abrir la publicación con el adaptador de Readium
            try await adapter.open(publication: record)
            
            // Registrar fecha de apertura
            var updatedRecord = record
            updatedRecord.lastOpenedAt = Date()
            try? await dependencies.publicationRepository.save(updatedRecord)
            
            // 3. Extraer la Tabla de Contenidos
            self.tocItems = (try? await adapter.tableOfContents()) ?? []
            
            self.isLoading = false
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
                deviceID: "iOS-Simulator",
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
        
        let title: String
        switch action {
        case "define":     title = "📖 Definición"
        case "translate":  title = "🌐 Traducción"
        case "explain":    title = "💡 Explicación"
        case "simplify":   title = "✏️ Simplificado"
        case "summarize":  title = "📄 Resumen"
        case "generateQuestions": title = "❓ Preguntas"
        default:           title = "✨ IA"
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
                switch action {
                case "define":
                    result = try await dependencies.aiService.explain(text: "Define la palabra: \(textToProcess)", sessionToken: token)
                case "translate":
                    result = try await dependencies.aiService.translate(text: textToProcess, targetLanguage: "en", sessionToken: token)
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
                    ForEach(HighlightCategory.allCases, id: \.self) { category in
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
                    
                    // Traducción directa con IA
                    Button {
                        triggerAIAction("translate")
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
        executeInlineAI(action: "define")
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
                
                Text("\"\(selectedText.prefix(120))\"")
                    .font(isPad ? AppTypography.body : AppTypography.caption)
                    .foregroundStyle(AppColor.textTertiary(for: theme))
                    .lineLimit(2)
                
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
                        Text(inlineBubbleText)
                            .font(isPad ? AppTypography.body : AppTypography.body) // Or custom size if needed
                            .foregroundStyle(AppColor.textPrimary(for: theme))
                            .lineSpacing(isPad ? 6 : 4)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: isPad ? 350 : 200)
                    
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
}
