import SwiftUI
import QuickLook
import PDFKit
import Translation

// MARK: - PresentationReaderView

/// Vista principal de lectura de presentaciones PowerPoint (`.ppt` y `.pptx`) y PDF de diapositivas.
///
/// Integra maquetación limpia sin barras laterales redundantes en iPad, herramientas de estudio completas de Lectoría
/// (resaltado por 5 colores, diccionario, traducción e IA), modo pantalla completa e historial de navegación.
struct PresentationReaderView: View {
    let record: PublicationRecord

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppDependencies.self) private var dependencies

    @State private var fileURL: URL?
    @State private var pdfDocument: PDFDocument? = nil
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showShareSheet = false
    @State private var sessionCoordinator: ReadingSessionCoordinator?

    // Control de navegación por páginas / diapositivas
    @State private var currentSlideIndex: Int = 0
    @State private var totalSlides: Int = 0
    @State private var lastJumpOriginIndex: Int? = nil
    @State private var showGoToPageDialog = false
    @State private var goToPageText = ""

    // Estados de interfaz adaptativa estilo Keynote
    @State private var isFullscreen = false
    @State private var showThumbnails = false
    @State private var notesSession = PresentationNotesSession()

    // Sistema de notas y anotaciones de Lectoría
    @State private var notes: [Note] = []
    @State private var presentationAnnotations: [PresentationAnnotation] = []
    @State private var activeSelectedText: String? = nil
    @State private var showAnnotationEditor = false
    @State private var textToTranslate: String? = nil
    @State private var showTranslationSheet = false

    // Panel flotante de selección y herramientas de estudio (5 Colores, Diccionario, Traducir e IA)
    @State private var hasSelection = false
    @State private var selectedText = ""
    @State private var showNoteEditor = false
    @State private var noteBody = ""
    @State private var noteTags = ""
    @State private var pendingCategory: HighlightCategory? = nil
    @State private var showPaywall = false
    @State private var showConsent = false
    @State private var pendingAIAction: String? = nil
    @State private var lastAIAction = ""
    @State private var translationConfig: TranslationSession.Configuration?
    @State private var inlineTranslationText = ""
    @State private var showInlineBubble = false
    @State private var inlineBubbleTitle = ""
    @State private var inlineBubbleText = ""
    @State private var isLoadingInline = false

    // Búsqueda (solo en la ruta PDF)
    @State private var showSearch = false
    @State private var searchQuery = ""
    @State private var searchMatches: [PDFSearchMatch] = []
    @State private var noteMatches: [PresentationSearchResult] = []
    @State private var activeMatchIndex: Int? = nil
    @State private var pendingSearchJump: Int? = nil
    @State private var pendingNoteJump: PresentationSearchResult? = nil
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>? = nil
    /// Notas del presentador por índice de diapositiva visible (= página del PDF).
    @State private var speakerNotes: [Int: String] = [:]

    /// Ruta PDF (PDFKit: búsqueda, resaltado, progreso) si el archivo es PDF o si ya existe el PDF
    /// convertido de la presentación. Se decide una sola vez al abrir: la vista nunca cambia de
    /// ruta mientras se lee; un PDF recién convertido se usa desde la siguiente apertura.
    @State private var usesPDFRoute: Bool

    init(record: PublicationRecord) {
        self.record = record
        let isPDF = record.localFileName.lowercased().hasSuffix(".pdf")
        var hasRendered = false
        if !isPDF, let directory = RenderedPresentationStore.publicationsDirectory() {
            let rendered = RenderedPresentationStore.renderedURL(forLocalFileName: record.localFileName, in: directory)
            hasRendered = FileManager.default.fileExists(atPath: rendered.path)
        }
        _usesPDFRoute = State(initialValue: isPDF || hasRendered)
    }

    private var hasNotesOnCurrentSlide: Bool {
        notes.contains { $0.anchor == "slide_\(currentSlideIndex + 1)" } ||
        presentationAnnotations.contains { $0.slideIndex == currentSlideIndex }
    }

    private var hasAnyNotesInPresentation: Bool {
        !notes.isEmpty || !presentationAnnotations.isEmpty
    }

    private var notesBadgeVisible: Bool {
        if isIndexableNavigationSupported {
            return hasNotesOnCurrentSlide
        } else {
            return hasAnyNotesInPresentation
        }
    }

    private var quickLookEffectiveAnchor: String {
        notesSession.quickLookAnchor(totalSlides: totalSlides)
    }

    private var quickLookEffectiveTitle: String {
        notesSession.quickLookTitle(totalSlides: totalSlides)
    }

    private var progressPercent: Double {
        guard totalSlides > 1 else { return totalSlides == 1 ? 1.0 : 0.0 }
        let clamped = max(0, min(currentSlideIndex, totalSlides - 1))
        return Double(clamped) / Double(totalSlides - 1)
    }

    private var progressPercentageText: String {
        guard totalSlides > 0 else { return "0%" }
        if totalSlides == 1 { return "100%" }
        return String(format: "%.0f%%", progressPercent * 100)
    }

    private var slideProgressDescription: String {
        guard totalSlides > 0 else {
            return String(localized: "Sin diapositivas", comment: "No slides progress label")
        }
        let currentHumanPage = min(currentSlideIndex + 1, totalSlides)
        return String(localized: "Diapositiva \(currentHumanPage) de \(totalSlides) · \(progressPercentageText)", comment: "Slide progress label")
    }

    private var isIndexableNavigationSupported: Bool {
        pdfDocument != nil
    }

    private var annotatedSlideIndices: Set<Int> {
        var set = Set(presentationAnnotations.map(\.slideIndex))
        for note in notes {
            if let anchor = note.anchor, anchor.hasPrefix("slide_"), let idx = Int(anchor.dropFirst(6)) {
                set.insert(idx - 1)
            }
        }
        return set
    }

    private var iphoneDrawerTitle: String {
        guard totalSlides > 0 else {
            return String(localized: "Sin diapositivas", comment: "Empty slides drawer title")
        }
        if !isIndexableNavigationSupported {
            return String(localized: "Diapositivas (\(totalSlides))", comment: "QuickLook slide count")
        } else {
            return String(localized: "Diapositivas (\(min(currentSlideIndex + 1, totalSlides))/\(totalSlides))", comment: "Slide drawer count")
        }
    }

    private var notesAccessibilityLabel: String {
        if isIndexableNavigationSupported {
            return String(localized: "Notas de esta diapositiva", comment: "Slide notes action label")
        } else {
            return String(localized: "Notas de la presentación", comment: "Presentation notes action label")
        }
    }

    private var notesAccessibilityValue: String {
        if isIndexableNavigationSupported {
            return hasNotesOnCurrentSlide
                ? String(localized: "Contiene notas", comment: "Slide has notes status")
                : String(localized: "Sin notas", comment: "Slide without notes status")
        } else {
            return hasAnyNotesInPresentation
                ? String(localized: "La presentación contiene notas", comment: "Presentation has notes status")
                : String(localized: "Sin notas", comment: "Presentation without notes status")
        }
    }

    private var notesAccessibilityHint: String {
        if isIndexableNavigationSupported {
            return String(localized: "Toca para abrir las notas y clasificaciones de esta diapositiva", comment: "Slide notes action hint")
        } else {
            return String(localized: "Toca para abrir o crear notas de la presentación", comment: "Presentation notes action hint")
        }
    }

    @ViewBuilder
    private func notesToolbarButton(theme: AppTheme) -> some View {
        Button {
            if notesSession.isSheetPresented {
                notesSession.close()
            } else {
                notesSession.open(isIndexableNavigationSupported: isIndexableNavigationSupported,
                                  currentSlideIndex: currentSlideIndex)
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "note.text")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(notesSession.isSheetPresented || notesBadgeVisible ? AppColor.accent(for: theme) : AppColor.textPrimary(for: theme))
                    .frame(width: 36, height: 36)
                    .background(AppColor.surfaceSecondary(for: theme))
                    .clipShape(Circle())

                if notesBadgeVisible {
                    Circle()
                        .fill(AppColor.accent(for: theme))
                        .frame(width: 8, height: 8)
                        .offset(x: -2, y: 2)
                }
            }
        }
        .accessibilityLabel(notesAccessibilityLabel)
        .accessibilityValue(notesAccessibilityValue)
        .accessibilityHint(notesAccessibilityHint)
    }

    @ViewBuilder
    private func topBar(theme: AppTheme) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.sm) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColor.textPrimary(for: theme))
                        .frame(width: 36, height: 36)
                        .background(AppColor.surfaceSecondary(for: theme))
                        .clipShape(Circle())
                }
                .accessibilityLabel(String(localized: "Volver", comment: "Back action label"))

                VStack(alignment: .leading, spacing: 2) {
                    Text(record.title)
                        .font(AppTypography.captionBold)
                        .foregroundStyle(AppColor.textPrimary(for: theme))
                        .lineLimit(1)

                    if isIndexableNavigationSupported {
                        Button {
                            guard totalSlides > 0 else { return }
                            goToPageText = "\(currentSlideIndex + 1)"
                            showGoToPageDialog = true
                        } label: {
                            Text(slideProgressDescription)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(totalSlides > 0 ? AppColor.accent(for: theme) : AppColor.textSecondary(for: theme))
                        }
                        .disabled(totalSlides <= 0)
                        .accessibilityLabel(String(localized: "Progreso de diapositivas", comment: "Slide progress label"))
                        .accessibilityValue(slideProgressDescription)
                        .accessibilityHint(String(localized: "Toca dos veces para ir a una diapositiva específica", comment: "Jump to slide hint"))
                    } else {
                        Text(String(localized: "Vista previa QuickLook · navegación mediante gestos", comment: "QuickLook navigation label"))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(AppColor.textSecondary(for: theme))
                            .accessibilityLabel(String(localized: "Modo de lectura QuickLook", comment: "QuickLook mode accessibility label"))
                            .accessibilityHint(String(localized: "Desliza para cambiar de diapositiva. QuickLook no reporta la diapositiva actual a la aplicación.", comment: "QuickLook navigation accessibility hint"))
                    }
                }

                Spacer()

                if pdfDocument != nil {
                    Button {
                        showSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(showSearch || activeMatchIndex != nil ? AppColor.accent(for: theme) : AppColor.textPrimary(for: theme))
                            .frame(width: 36, height: 36)
                            .background(AppColor.surfaceSecondary(for: theme))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(String(localized: "Buscar en la presentación", comment: "Presentation search button"))
                }

                // Botón Notas
                notesToolbarButton(theme: theme)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isFullscreen.toggle()
                    }
                } label: {
                    Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColor.textPrimary(for: theme))
                        .frame(width: 36, height: 36)
                        .background(AppColor.surfaceSecondary(for: theme))
                        .clipShape(Circle())
                }
                .accessibilityLabel(String(localized: "Pantalla completa", comment: "Toggle fullscreen label"))

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showThumbnails.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(showThumbnails ? AppColor.accent(for: theme) : AppColor.textPrimary(for: theme))
                        .frame(width: 36, height: 36)
                        .background(AppColor.surfaceSecondary(for: theme))
                        .clipShape(Circle())
                }
                .accessibilityLabel(String(localized: "Miniaturas de diapositivas", comment: "Toggle thumbnail strip"))

                if let fileURL {
                    ShareLink(item: fileURL) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppColor.textPrimary(for: theme))
                            .frame(width: 36, height: 36)
                            .background(AppColor.surfaceSecondary(for: theme))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(String(localized: "Compartir presentación", comment: "Share presentation label"))
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs)
            .background(AppColor.surface(for: theme))

            if isIndexableNavigationSupported && totalSlides > 1 {
                ProgressView(value: progressPercent, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: AppColor.accent(for: theme)))
                    .frame(height: 2)
            }

            Divider()
                .background(AppColor.border(for: theme))
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    @ViewBuilder
    private func iphoneDrawerHandle(theme: AppTheme) -> some View {
        HStack {
            Spacer()
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showThumbnails = true
                }
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "chevron.left")
                        .font(.caption2.weight(.bold))
                    Image(systemName: "sidebar.right")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(AppColor.accent(for: theme))
                .padding(.horizontal, 6)
                .padding(.vertical, 10)
                .background(AppColor.surface(for: theme))
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: AppRadius.sm, bottomLeadingRadius: AppRadius.sm))
                .shadow(color: AppShadow.medium(for: theme).color, radius: AppShadow.medium(for: theme).radius, x: -2, y: 0)
            }
            .accessibilityLabel(String(localized: "Abrir miniaturas de diapositivas", comment: "Open thumbnail drawer label"))
            .accessibilityHint(String(localized: "Muestra la lista de diapositivas en un panel lateral", comment: "Open thumbnail drawer hint"))
        }
        .transition(.move(edge: .trailing))
    }

    @ViewBuilder
    private func iphoneDrawer(theme: AppTheme) -> some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showThumbnails = false
                    }
                }
                .transition(.opacity)

            HStack(spacing: 0) {
                Spacer()

                VStack(spacing: 0) {
                    HStack {
                        Text(iphoneDrawerTitle)
                            .font(AppTypography.captionBold)
                            .foregroundStyle(AppColor.textSecondary(for: theme))

                        Spacer()

                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showThumbnails = false
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(AppColor.textTertiary(for: theme))
                        }
                        .accessibilityLabel(String(localized: "Cerrar panel de diapositivas", comment: "Close thumbnail drawer label"))
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.xs)

                    Divider()
                        .background(AppColor.border(for: theme))

                    PresentationThumbnailStripView(
                        pdfDocument: pdfDocument,
                        fileURL: fileURL,
                        totalSlides: totalSlides,
                        currentSlideIndex: $currentSlideIndex,
                        isVertical: true,
                        slidesWithNotesOrAnnotations: annotatedSlideIndices,
                        canNavigate: isIndexableNavigationSupported,
                        onSelectSlide: { index in
                            guard isIndexableNavigationSupported else { return }
                            if index != currentSlideIndex {
                                lastJumpOriginIndex = currentSlideIndex
                                currentSlideIndex = index
                            }
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showThumbnails = false
                            }
                        }
                    )
                }
                .background(AppColor.surface(for: theme))
                .shadow(color: AppShadow.medium(for: theme).color, radius: AppShadow.medium(for: theme).radius, x: -4, y: 0)
            }
            .transition(.move(edge: .trailing))
            .gesture(
                DragGesture()
                    .onEnded { value in
                        if value.translation.width > 50 {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showThumbnails = false
                            }
                        }
                    }
            )
        }
    }

    @ViewBuilder
    private func notesSheetView(theme: AppTheme) -> some View {
        NavigationStack {
            VStack(spacing: AppSpacing.sm) {
                if isIndexableNavigationSupported {
                    PresentationNotesPanelView(
                        slideIndex: notesSession.pdfTargetSlideIndex,
                        totalSlides: totalSlides,
                        existingNotes: notes,
                        customAnchor: notesSession.pdfAnchor(),
                        customTitle: String(localized: "Notas de la diapositiva \(notesSession.pdfTargetSlideIndex + 1)", comment: "Notes sheet title"),
                        initiallyExpanded: true,
                        onSaveNote: { text, category in
                            guard notesSession.pdfTargetSlideIndex >= 0,
                                  notesSession.pdfTargetSlideIndex < totalSlides else { return }
                            let targetAnchor = notesSession.pdfAnchor()
                            let newNote = Note(
                                publicationID: record.id,
                                anchor: targetAnchor,
                                body: text,
                                tags: [category.rawValue]
                            )
                            notes.append(newNote)
                        }
                    )
                } else {
                    VStack(spacing: AppSpacing.xs) {
                        HStack(alignment: .top, spacing: AppSpacing.xs) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(AppColor.warning(for: theme))
                                .font(.subheadline)
                            Text(String(localized: "QuickLook no puede detectar automáticamente la diapositiva visible.", comment: "QuickLook notes disclaimer"))
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColor.textSecondary(for: theme))
                            Spacer()
                        }
                        .padding(AppSpacing.sm)
                        .background(AppColor.surfaceSecondary(for: theme))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                        .padding(.horizontal, AppSpacing.md)

                        if totalSlides > 0 {
                            HStack {
                                Text(String(localized: "Destino:", comment: "Note destination label"))
                                    .font(AppTypography.captionBold)
                                    .foregroundStyle(AppColor.textSecondary(for: theme))
                                Spacer()
                                Picker(String(localized: "Destino de la nota", comment: "Note destination picker"), selection: $notesSession.quickLookNoteOption) {
                                    Text(String(localized: "Nota general de la presentación", comment: "General note option"))
                                        .tag(-1)
                                    ForEach(0..<totalSlides, id: \.self) { idx in
                                        Text(String(localized: "Diapositiva \(idx + 1)", comment: "Slide option"))
                                            .tag(idx)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            .padding(.horizontal, AppSpacing.md)
                        }

                        PresentationNotesPanelView(
                            slideIndex: max(0, notesSession.quickLookNoteOption),
                            totalSlides: totalSlides,
                            existingNotes: notes,
                            customAnchor: quickLookEffectiveAnchor,
                            customTitle: quickLookEffectiveTitle,
                            initiallyExpanded: true,
                            onSaveNote: { text, category in
                                let targetAnchor = quickLookEffectiveAnchor
                                let newNote = Note(
                                    publicationID: record.id,
                                    anchor: targetAnchor,
                                    body: text,
                                    tags: [category.rawValue]
                                )
                                notes.append(newNote)
                            }
                        )
                    }
                }
                Spacer()
            }
            .navigationTitle(isIndexableNavigationSupported
                ? String(localized: "Notas de la diapositiva", comment: "Notes sheet title")
                : String(localized: "Notas de la presentación", comment: "QuickLook notes sheet title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cerrar", comment: "Close notes sheet")) {
                        notesSession.close()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    var body: some View {
        Group {
            if usesPDFRoute {
                pdfReaderBody
            } else {
                simplePresentationBody
            }
        }
    }

    private var simplePresentationBody: some View {
        let theme = themeManager.currentTheme
        return VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .padding(AppSpacing.sm)
                }
                .accessibilityLabel("Volver")
                Text(record.title)
                    .font(AppTypography.captionBold)
                    .lineLimit(1)
                Spacer()
                if let fileURL {
                    ShareLink(item: fileURL) {
                        Image(systemName: "square.and.arrow.up")
                            .padding(AppSpacing.sm)
                    }
                    .accessibilityLabel("Compartir presentación")
                }
            }
            .padding(.horizontal, AppSpacing.sm)
            .foregroundStyle(AppColor.textPrimary(for: theme))
            .background(AppColor.surface(for: theme))
            Divider()
            if let fileURL, errorMessage == nil {
                QuickLookPreviewWrapper(fileURL: fileURL)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                errorView(message: errorMessage, theme: theme)
            } else {
                ProgressView("Cargando presentación…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task { await resolveAndPrepareFile() }
        .onChange(of: scenePhase) { _, phase in
            sessionCoordinator?.handleScenePhaseChange(phase)
        }
        .onDisappear { sessionCoordinator?.endSession() }
    }

    @ViewBuilder
    private var pdfReaderBody: some View {
        let theme = themeManager.currentTheme

        ZStack {
            VStack(spacing: 0) {
                // 1. Barra de herramientas superior personalizada (ocultable en pantalla completa)
                if !isFullscreen {
                    topBar(theme: theme)
                }

                // 2. Área Central de Lectura + QuickView (Miniaturas al lado derecho)
                HStack(spacing: 0) {
                    ZStack(alignment: .bottom) {
                        AppColor.background(for: theme)
                            .ignoresSafeArea()
                            .onTapGesture {
                                if !hasSelection && !showInlineBubble {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        isFullscreen.toggle()
                                    }
                                }
                            }

                        if let pdfDoc = pdfDocument {
                            // Ruta A: PDFKit con Selección y Resaltado por Colores de Lectoría
                            PDFPresentationPreviewWrapper(
                                pdfDocument: pdfDoc,
                                pageIndex: $currentSlideIndex,
                                annotations: presentationAnnotations,
                                onTextSelected: { text, bounds, slideIdx in
                                    activeSelectedText = text
                                    selectedText = text
                                    hasSelection = true
                                },
                                onSelectionCleared: {
                                    hasSelection = false
                                    selectedText = ""
                                },
                                onAddNoteRequest: { text, slideIdx in
                                    activeSelectedText = text
                                    selectedText = text
                                    noteBody = ""
                                    noteTags = ""
                                    showNoteEditor = true
                                },
                                onTranslateRequest: { text in
                                    selectedText = text
                                    triggerAIAction("translate_en")
                                },
                                searchMatches: searchMatches,
                                activeSearchIndex: activeMatchIndex
                            )
                        } else if let fileURL, errorMessage == nil {
                            // Ruta B: Quick Look nativo del original (.ppt / .pptx)
                            QuickLookPreviewWrapper(fileURL: fileURL)
                        } else if isLoading {
                            VStack(spacing: AppSpacing.md) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                    .tint(AppColor.accent(for: theme))
                                Text(String(localized: "Cargando presentación…", comment: "Reader: loading presentation"))
                                    .font(AppTypography.body)
                                    .foregroundStyle(AppColor.textSecondary(for: theme))
                            }
                        } else if let errorMessage {
                            errorView(message: errorMessage, theme: theme)
                        }

                        // Botón flotante para salir de pantalla completa
                        if isFullscreen {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isFullscreen = false
                                }
                            } label: {
                                Image(systemName: "arrow.down.right.and.arrow.up.left")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(AppSpacing.xs)
                                    .background(AppColor.surface(for: theme).opacity(0.85))
                                    .foregroundStyle(AppColor.textPrimary(for: theme))
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                            }
                            .padding(.bottom, AppSpacing.md)
                        }

                        // Botón flotante para volver a la diapositiva previa tras un salto
                        if let activeIndex = activeMatchIndex, !searchMatches.isEmpty, !showSearch, !isFullscreen {
                            ReaderSearchNavigatorBar(
                                query: searchQuery,
                                activeIndex: activeIndex,
                                total: searchMatches.count,
                                theme: theme,
                                onPrevious: { selectSearchMatch(at: (activeIndex - 1 + searchMatches.count) % searchMatches.count) },
                                onNext: { selectSearchMatch(at: (activeIndex + 1) % searchMatches.count) },
                                onShowList: { showSearch = true },
                                onClose: { clearSearch() }
                            )
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.bottom, AppSpacing.sm)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else if let originIndex = lastJumpOriginIndex, originIndex != currentSlideIndex, !isFullscreen {
                            Button {
                                lastJumpOriginIndex = nil
                                currentSlideIndex = originIndex
                            } label: {
                                HStack(spacing: AppSpacing.xs) {
                                    Image(systemName: "arrow.uturn.backward.circle.fill")
                                        .font(.subheadline)
                                    Text(String(localized: "Volver a pág. \(originIndex + 1)", comment: "Reader: jump back button"))
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
                            .padding(.bottom, AppSpacing.sm)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }

                    // QuickView: Tira de miniaturas lateral fija para iPad
                    if horizontalSizeClass == .regular && showThumbnails && !isFullscreen {
                        Divider()
                            .background(AppColor.border(for: theme))

                        PresentationThumbnailStripView(
                            pdfDocument: pdfDocument,
                            fileURL: fileURL,
                            totalSlides: totalSlides,
                            currentSlideIndex: $currentSlideIndex,
                            isVertical: true,
                            slidesWithNotesOrAnnotations: annotatedSlideIndices,
                            canNavigate: isIndexableNavigationSupported,
                            onSelectSlide: { index in
                                guard isIndexableNavigationSupported else { return }
                                if index != currentSlideIndex {
                                    lastJumpOriginIndex = currentSlideIndex
                                    currentSlideIndex = index
                                }
                            }
                        )
                        .transition(.move(edge: .trailing))
                    }
                }
            }
            .background(
                AppColor.surface(for: theme)
                    .shadow(color: AppShadow.subtle(for: theme).color,
                            radius: AppShadow.subtle(for: theme).radius,
                            x: AppShadow.subtle(for: theme).x,
                            y: AppShadow.subtle(for: theme).y)
            )

            // QuickView iPhone: Tirador / Tirilla de apertura en el borde derecho cuando el panel está oculto
            if horizontalSizeClass == .compact && !showThumbnails && !isFullscreen {
                iphoneDrawerHandle(theme: theme)
            }

            // QuickView iPhone: Panel superpuesto deslizable (Drawer) al tocar tirador o deslizar desde borde
            if horizontalSizeClass == .compact && showThumbnails && !isFullscreen {
                iphoneDrawer(theme: theme)
            }

            // Panel flotante de selección (Menú con 5 Colores, Diccionario, Traducción e IA)
            if hasSelection && !selectedText.isEmpty {
                selectionFloatingToolbar(theme: theme)
                    .transition(.opacity)
            }

            // Globo flotante de respuesta inline (Diccionario, Traducción, IA)
            if showInlineBubble {
                inlineResponseBubble(theme: theme)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .alert(String(localized: "Ir a página", comment: "Presentation jump alert title"), isPresented: $showGoToPageDialog) {
            TextField(String(localized: "Número de diapositiva (1-\(max(1, totalSlides)))", comment: "Slide textfield placeholder"), text: $goToPageText)
                .keyboardType(.numberPad)
            Button(String(localized: "Ir", comment: "Go to slide confirm")) {
                let trimmed = goToPageText.trimmingCharacters(in: .whitespacesAndNewlines)
                if let page = Int(trimmed), page >= 1 && page <= totalSlides {
                    let targetIndex = page - 1
                    if targetIndex != currentSlideIndex {
                        lastJumpOriginIndex = currentSlideIndex
                        currentSlideIndex = targetIndex
                    }
                }
            }
            Button(String(localized: "Cancelar", comment: "Cancel button"), role: .cancel) {}
        } message: {
            Text(String(localized: "Introduce el número de diapositiva al que deseas saltar.", comment: "Go to slide alert message"))
        }
        .task {
            await resolveAndPrepareFile()
        }
        .onChange(of: currentSlideIndex) { _, newIndex in
            saveSlideProgress(newIndex)
        }
        .onChange(of: totalSlides) { _, newTotal in
            if newTotal <= 0 {
                currentSlideIndex = 0
            } else if currentSlideIndex >= newTotal {
                currentSlideIndex = newTotal - 1
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            sessionCoordinator?.handleScenePhaseChange(newPhase)
        }
        .onDisappear {
            sessionCoordinator?.endSession()
            searchTask?.cancel()
        }
        .sheet(isPresented: $showSearch, onDismiss: {
            if let index = pendingSearchJump {
                pendingSearchJump = nil
                selectSearchMatch(at: index)
            } else if let note = pendingNoteJump {
                pendingNoteJump = nil
                showSpeakerNote(note)
            }
        }) {
            searchSheet(theme: theme)
        }
        .sheet(isPresented: $notesSession.isSheetPresented, onDismiss: {
            notesSession.close()
        }) {
            notesSheetView(theme: theme)
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
        .sheet(isPresented: $showAnnotationEditor) {
            if let selectedText = activeSelectedText {
                PresentationAnnotationEditorSheet(
                    selectedText: selectedText,
                    slideIndex: currentSlideIndex,
                    documentID: record.id.uuidString,
                    onSave: { newAnn in
                        presentationAnnotations.append(newAnn)
                        let newNote = Note(
                            publicationID: record.id,
                            anchor: "slide_\(currentSlideIndex + 1)",
                            body: "“\(newAnn.selectedText)”\n\(newAnn.userComment ?? "")",
                            tags: [newAnn.categoryID ?? "Importante"]
                        )
                        notes.append(newNote)
                    }
                )
            }
        }
        .translationTask(translationConfig) { session in
            let text = inlineTranslationText
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
        .sheet(isPresented: $showTranslationSheet) {
            if let textToTranslate {
                TranslationSheetView(originalText: textToTranslate)
            }
        }
    }

    // MARK: - Selection Floating Toolbar (5 Colores, Diccionario, Traducir, IA)

    private func selectionFloatingToolbar(theme: AppTheme) -> some View {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let circleSize: CGFloat = isPad ? 40 : 32

        return VStack {
            Spacer()

            VStack(spacing: isPad ? AppSpacing.md : AppSpacing.sm) {
                // Fila 1: Colores de subrayado por categorías de Lectoría
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
                        hasSelection = false
                        selectedText = ""
                        activeSelectedText = nil
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

                    // Menú IA Lectoría
                    Menu {
                        Button(action: { triggerAIAction("explain") }) {
                            Label("Explicar concepto", systemImage: "lightbulb")
                        }
                        Button(action: { triggerAIAction("define") }) {
                            Label("Definir término", systemImage: "book")
                        }
                        Button(action: { triggerAIAction("simplify") }) {
                            Label("Simplificar texto", systemImage: "text.alignleft")
                        }
                        Button(action: { triggerAIAction("summarize") }) {
                            Label("Resumir selección", systemImage: "doc.text")
                        }
                        Button(action: { triggerAIAction("generateQuestions") }) {
                            Label("Generar preguntas de estudio", systemImage: "questionmark.bubble")
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(isPad ? .body : .callout)
                            Text("+ IA")
                                .font(isPad ? AppTypography.bodyBold : AppTypography.captionBold)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, isPad ? AppSpacing.md : AppSpacing.sm)
                        .padding(.vertical, isPad ? AppSpacing.xs : AppSpacing.xxs)
                        .background(
                            LinearGradient(
                                colors: [AppColor.accent(for: theme), Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: Color.purple.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                }
            }
            .padding(isPad ? AppSpacing.lg : AppSpacing.md)
            .background(
                AppColor.surface(for: theme)
                    .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 4)
            )
            .clipShape(RoundedRectangle(cornerRadius: isPad ? AppRadius.lg : AppRadius.md))
            .padding(.horizontal, isPad ? AppSpacing.xxl : AppSpacing.md)
            .padding(.bottom, isPad ? 70 : 60)
        }
    }

    // MARK: - Inline AI / Dictionary Response Bubble

    private func inlineResponseBubble(theme: AppTheme) -> some View {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad

        return VStack {
            Spacer()

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    Text(inlineBubbleTitle)
                        .font(isPad ? AppTypography.title2 : AppTypography.bodyBold)
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
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(AppColor.textTertiary(for: theme))
                    }
                }

                if isLoadingInline {
                    HStack(spacing: AppSpacing.md) {
                        ProgressView()
                            .tint(AppColor.accent(for: theme))
                        Text("Procesando con IA...")
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColor.textSecondary(for: theme))
                    }
                    .padding(.vertical, AppSpacing.sm)
                } else {
                    ScrollView {
                        Text(AttributedString.inlineMarkdown(inlineBubbleText))
                            .font(AppTypography.body)
                            .foregroundStyle(AppColor.textPrimary(for: theme))
                            .textSelection(.enabled)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxHeight: isPad ? 220 : 160)
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

                TextField("Etiquetas (separadas por coma)", text: $noteTags)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, AppSpacing.lg)

                Spacer()
            }
            .background(AppColor.background(for: theme))
            .navigationTitle("Añadir nota de estudio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { showNoteEditor = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let cat = pendingCategory ?? .mainIdea
                        createHighlight(category: cat, customNoteBody: noteBody)
                        showNoteEditor = false
                    }
                    .font(AppTypography.bodyBold)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Study Actions (Colors, Dictionary, AI)

    private func categoryColor(_ category: HighlightCategory) -> Color {
        switch category {
        case .mainIdea: Color(red: 0.95, green: 0.77, blue: 0.06)
        case .evidence: Color(red: 0.20, green: 0.60, blue: 0.86)
        case .action: Color(red: 0.18, green: 0.80, blue: 0.44)
        case .question: Color(red: 0.91, green: 0.30, blue: 0.24)
        case .quote: Color(red: 0.90, green: 0.49, blue: 0.13)
        case .dictionary: Color.blue
        case .translation: Color.green
        case .ai: Color.purple
        }
    }

    private func createHighlight(category: HighlightCategory, customNoteBody: String? = nil) {
        let textToHighlight = selectedText.isEmpty ? (activeSelectedText ?? "") : selectedText
        guard !textToHighlight.isEmpty else { return }

        let newAnn = PresentationAnnotation(
            documentID: record.id.uuidString,
            slideID: "slide_\(currentSlideIndex + 1)",
            slideIndex: currentSlideIndex,
            selectedText: textToHighlight,
            categoryID: category.rawValue,
            userComment: customNoteBody
        )
        presentationAnnotations.append(newAnn)

        if let customNoteBody, !customNoteBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let note = Note(
                publicationID: record.id,
                anchor: "slide_\(currentSlideIndex + 1)",
                body: customNoteBody,
                tags: [category.rawValue]
            )
            notes.append(note)
        }

        hasSelection = false
        selectedText = ""
        activeSelectedText = nil
    }

    private func showDictionary(for term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if UIReferenceLibraryViewController.dictionaryHasDefinition(forTerm: trimmed) {
            let dictVC = UIReferenceLibraryViewController(term: trimmed)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(dictVC, animated: true)
            }
        } else {
            triggerAIAction("define")
        }
    }

    private func triggerAIAction(_ actionName: String) {
        Task {
            // La traducción local es una función Premium con su propio permiso
            // y no consume el cupo de IA ni requiere consentimiento de IA generativa.
            if actionName.hasPrefix("translate_") {
                let access = await dependencies.entitlementService.canAccess(.useLocalTranslation)
                guard access == .allowed else {
                    await MainActor.run { self.showPaywall = true }
                    return
                }
                await MainActor.run {
                    executeInlineAI(action: actionName)
                }
                return
            }

            let canPerform = await dependencies.entitlementService.canPerformAction(.performAIAction)
            guard canPerform else {
                await MainActor.run { self.showPaywall = true }
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

    private func executeInlineAI(action: String) {
        let textToProcess = selectedText.isEmpty ? (activeSelectedText ?? "") : selectedText
        guard !textToProcess.isEmpty else { return }

        let title: String
        if action.hasPrefix("translate") {
            title = "🌐 Traducción"
        } else {
            switch action {
            case "define": title = "📖 Definición"
            case "explain": title = "💡 Explicación"
            case "simplify": title = "✏️ Simplificado"
            case "summarize": title = "📄 Resumen"
            case "generateQuestions": title = "❓ Preguntas"
            default: title = "✨ IA"
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
            inlineTranslationText = textToProcess
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
                case "define": result = try await dependencies.aiService.explain(text: "Define el término: \(textToProcess)", sessionToken: token)
                case "explain": result = try await dependencies.aiService.explain(text: textToProcess, sessionToken: token)
                case "simplify": result = try await dependencies.aiService.simplify(text: textToProcess, sessionToken: token)
                case "summarize": result = try await dependencies.aiService.summarize(text: textToProcess, sessionToken: token)
                case "generateQuestions": result = try await dependencies.aiService.generateQuestions(text: textToProcess, sessionToken: token)
                default: result = ""
                }

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

    // MARK: - File Resolution

    private func resolveAndPrepareFile() async {
        isLoading = true
        errorMessage = nil

        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            errorMessage = String(localized: "No se pudo acceder al directorio de almacenamiento.", comment: "Storage error")
            isLoading = false
            return
        }

        let targetURL = appSupport.appendingPathComponent("Publications/\(record.localFileName)")

        var finalURL: URL?
        if FileManager.default.fileExists(atPath: targetURL.path) {
            finalURL = targetURL
        } else {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(record.localFileName)
            if FileManager.default.fileExists(atPath: tempURL.path) {
                finalURL = tempURL
            }
        }

        if let validURL = finalURL {
            // `fileURL` sigue siendo el original: es lo que se comparte o exporta.
            self.fileURL = validURL
            if validURL.pathExtension.lowercased() == "pdf", let pdf = PDFDocument(url: validURL) {
                self.pdfDocument = pdf
                self.totalSlides = pdf.pageCount
            } else if usesPDFRoute, let rendered = renderedDocument(nextTo: validURL) {
                self.pdfDocument = rendered
                self.totalSlides = rendered.pageCount
            } else {
                self.pdfDocument = nil
                self.totalSlides = 0
            }

            if pdfDocument == nil, RenderedPresentationStore.isConvertible(localFileName: record.localFileName) {
                // Sin PDF (o ilegible): se lee con QuickLook y se convierte en segundo plano.
                let renderer = dependencies.presentationRenderingService
                let localFileName = record.localFileName
                let publicationID = record.id
                Task { await renderer.ensureRendered(localFileName: localFileName, publicationID: publicationID) }
            }

            if pdfDocument != nil, RenderedPresentationStore.isConvertible(localFileName: record.localFileName) {
                loadSpeakerNotes(from: validURL)
            }

            if pdfDocument != nil {
                let saved = try? await dependencies.readingProgressRepository.fetchProgress(forPublication: record.id)
                self.currentSlideIndex = PresentationProgress.resumeIndex(savedPageNumber: saved?.pageNumber, totalSlides: totalSlides)
            }

            if self.totalSlides <= 0 {
                self.currentSlideIndex = 0
            } else if self.currentSlideIndex >= self.totalSlides {
                self.currentSlideIndex = self.totalSlides - 1
            }
            self.isLoading = false

            if sessionCoordinator == nil {
                let coordinator = ReadingSessionCoordinator(
                    publicationID: record.id,
                    format: record.publicationType.analyticsFormat,
                    analyticsService: dependencies.analyticsService,
                    readingSessionRepository: dependencies.readingSessionRepository,
                    progressProvider: {
                        // QuickLook no informa la diapositiva: solo hay progreso en la ruta PDF.
                        guard pdfDocument != nil else { return nil }
                        return PresentationProgress.percentage(slideIndex: currentSlideIndex, totalSlides: totalSlides)
                    }
                )
                coordinator.startSession()
                self.sessionCoordinator = coordinator
            }
        } else {
            self.errorMessage = String(localized: "El archivo de la presentación no fue encontrado en el almacenamiento local.", comment: "File missing error")
            self.isLoading = false
        }
    }

    // MARK: - Búsqueda

    private func searchSheet(theme: AppTheme) -> some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(AppColor.textSecondary(for: theme))
                    TextField(String(localized: "Buscar en las diapositivas…", comment: "Presentation search placeholder"), text: $searchQuery)
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
                        .accessibilityLabel(String(localized: "Borrar búsqueda", comment: "Clear search"))
                    }
                }
                .padding(AppSpacing.md)
                .background(AppColor.surfaceSecondary(for: theme))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.sm)

                Divider().background(AppColor.border(for: theme))

                if isSearching {
                    VStack(spacing: AppSpacing.xs) {
                        Spacer()
                        ProgressView().tint(AppColor.accent(for: theme))
                        Text(String(localized: "Buscando…", comment: "Searching"))
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColor.textSecondary(for: theme))
                        Spacer()
                    }
                } else if searchMatches.isEmpty && noteMatches.isEmpty && !searchQuery.isEmpty {
                    VStack {
                        Spacer()
                        Text(String(localized: "No se encontraron resultados.", comment: "No search results"))
                            .font(AppTypography.body)
                            .foregroundStyle(AppColor.textSecondary(for: theme))
                        Spacer()
                    }
                } else {
                    List {
                        if !searchMatches.isEmpty {
                            Section {
                                ForEach(Array(searchMatches.enumerated()), id: \.element.id) { index, match in
                                    Button {
                                        activeMatchIndex = index
                                        pendingSearchJump = index
                                        showSearch = false
                                    } label: {
                                        searchRow(title: match.pageTitle, snippet: match.snippet, theme: theme)
                                    }
                                    .listRowBackground(
                                        index == activeMatchIndex
                                            ? AppColor.accent(for: theme).opacity(0.12)
                                            : AppColor.surface(for: theme)
                                    )
                                }
                            } header: {
                                Text(PresentationSearchText.slideSummary(
                                    matchCount: searchMatches.count,
                                    slideCount: PDFTextSearch.pageCount(of: searchMatches)
                                ))
                            }
                        }
                        if !noteMatches.isEmpty {
                            Section {
                                ForEach(noteMatches) { note in
                                    Button {
                                        pendingNoteJump = note
                                        showSearch = false
                                    } label: {
                                        searchRow(
                                            title: String(localized: "Diapositiva \(note.slideIndex + 1)", comment: "Presentation search: slide N"),
                                            snippet: AttributedString(note.matchSnippet),
                                            theme: theme
                                        )
                                    }
                                    .listRowBackground(AppColor.surface(for: theme))
                                }
                            } header: {
                                Text(String(localized: "En notas del presentador", comment: "Presentation search: speaker notes section"))
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(AppColor.background(for: theme))
            .navigationTitle(String(localized: "Buscar en la presentación", comment: "Presentation search title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Cerrar", comment: "Close")) { showSearch = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func searchRow(title: String, snippet: AttributedString, theme: AppTheme) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(title)
                .font(AppTypography.footnote.weight(.semibold))
                .foregroundStyle(AppColor.accent(for: theme))
            Text(snippet)
                .font(AppTypography.body)
                .foregroundStyle(AppColor.textPrimary(for: theme))
                .lineLimit(2)
        }
    }

    private func performSearch() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, let document = pdfDocument else { return }
        searchTask?.cancel()
        isSearching = true
        activeMatchIndex = nil
        searchMatches = []
        noteMatches = []
        let notes = speakerNotes
        searchTask = Task { @MainActor in
            // Ceder un ciclo para que se pinte "Buscando…" antes de recorrer el PDF.
            await Task.yield()
            guard !Task.isCancelled else { return }
            let matches = PDFTextSearch.search(query, in: document, pageLabel: { index in
                String(localized: "Diapositiva \(index + 1)", comment: "Presentation search: slide N")
            })
            let inNotes = PresentationSearchEngine(slideTexts: [:], presenterNotes: notes)
                .search(query: query)
                .filter(\.isPresenterNote)
            guard !Task.isCancelled else { return }
            searchMatches = matches
            noteMatches = inNotes
            isSearching = false
        }
    }

    /// Activa la coincidencia `index`: la sombrea en naranja y salta a su diapositiva.
    private func selectSearchMatch(at index: Int) {
        guard searchMatches.indices.contains(index) else { return }
        let target = searchMatches[index].pageIndex
        withAnimation(.easeInOut(duration: 0.2)) {
            activeMatchIndex = index
        }
        if target != currentSlideIndex {
            if lastJumpOriginIndex == nil { lastJumpOriginIndex = currentSlideIndex }
            currentSlideIndex = target
        }
    }

    private func clearSearch() {
        searchTask?.cancel()
        searchQuery = ""
        searchMatches = []
        noteMatches = []
        pendingSearchJump = nil
        pendingNoteJump = nil
        isSearching = false
        withAnimation(.easeInOut(duration: 0.2)) {
            activeMatchIndex = nil
        }
    }

    /// Las notas del presentador no están en el PDF: se salta a su diapositiva y se muestran
    /// completas en el globo inferior, sin sombreado.
    private func showSpeakerNote(_ note: PresentationSearchResult) {
        if note.slideIndex != currentSlideIndex, note.slideIndex < max(1, totalSlides) {
            lastJumpOriginIndex = currentSlideIndex
            currentSlideIndex = note.slideIndex
        }
        withAnimation(.spring(response: 0.3)) {
            inlineBubbleTitle = String(localized: "Notas del presentador", comment: "Speaker notes bubble title")
            inlineBubbleText = speakerNotes[note.slideIndex] ?? note.matchSnippet
            isLoadingInline = false
            showInlineBubble = true
        }
    }

    /// Lee las notas del presentador del `.pptx` original, indexadas como las páginas del PDF.
    private func loadSpeakerNotes(from original: URL) {
        Task {
            guard let slides = try? await PPTXParser.visibleSlides(url: original) else { return }
            var notes: [Int: String] = [:]
            for (index, slide) in slides.enumerated() {
                if let text = slide.speakerNotes, !text.isEmpty { notes[index] = text }
            }
            speakerNotes = notes
        }
    }

    /// PDF convertido junto al original, solo si es válido (si no, se usa QuickLook).
    private func renderedDocument(nextTo original: URL) -> PDFDocument? {
        let rendered = RenderedPresentationStore.renderedURL(
            forLocalFileName: original.lastPathComponent,
            in: original.deletingLastPathComponent()
        )
        return RenderedPresentationStore.validDocument(at: rendered)
    }

    /// Guarda la diapositiva actual para reanudar y para las estadísticas ("terminados").
    private func saveSlideProgress(_ index: Int) {
        guard pdfDocument != nil, totalSlides > 0 else { return }
        let progress = ReadingProgress(
            publicationID: record.id,
            locatorJSON: "{\"slideIndex\":\(index)}",
            percentage: PresentationProgress.percentage(slideIndex: index, totalSlides: totalSlides),
            pageNumber: index + 1,
            chapterTitle: "Diapositiva \(index + 1)",
            deviceID: "iOS-Simulator",
            version: 1
        )
        let repository = dependencies.readingProgressRepository
        Task { try? await repository.saveProgress(progress) }
    }

    // MARK: - Error View

    private func errorView(message: String, theme: AppTheme) -> some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppColor.warning(for: theme))

            VStack(spacing: AppSpacing.xs) {
                Text(String(localized: "Error de lectura", comment: "Presentation error title"))
                    .font(AppTypography.title2)
                    .foregroundStyle(AppColor.textPrimary(for: theme))

                Text(message)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColor.textSecondary(for: theme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }

            HStack(spacing: AppSpacing.md) {
                Button {
                    Task {
                        await resolveAndPrepareFile()
                    }
                } label: {
                    Label(String(localized: "Reintentar", comment: "Retry button"), systemImage: "arrow.clockwise")
                        .font(AppTypography.callout.weight(.semibold))
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(AppColor.accent(for: theme))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }

                Button {
                    dismiss()
                } label: {
                    Text(String(localized: "Volver a la Biblioteca", comment: "Back button"))
                        .font(AppTypography.callout)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(AppColor.surfaceSecondary(for: theme))
                        .foregroundStyle(AppColor.textPrimary(for: theme))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(AppSpacing.xl)
    }
}

// MARK: - PresentationNotesCoordinator & PresentationNotesSession

/// Coordinador y resolutor centralizado de destinos para notas en presentaciones (QuickLook y PDF).
public enum PresentationNotesCoordinator {
    public static let generalNoteOption: Int = -1
    public static let generalAnchor: String = "presentation_general"

    /// Determina la opción inicial al abrir el panel en QuickLook: siempre -1 ("Nota general de la presentación").
    public static func initialQuickLookOption() -> Int {
        generalNoteOption
    }

    /// Resuelve el anchor de la nota para QuickLook según la opción seleccionada y el número de diapositivas.
    public static func quickLookAnchor(forOption option: Int, totalSlides: Int) -> String {
        if option < 0 || option >= totalSlides {
            return generalAnchor
        } else {
            return "slide_\(option + 1)"
        }
    }

    /// Resuelve el título descriptivo para la nota de QuickLook.
    public static func quickLookTitle(forOption option: Int, totalSlides: Int) -> String {
        if option < 0 || option >= totalSlides {
            return String(localized: "Nota general de la presentación", comment: "General presentation note title")
        } else {
            return String(localized: "Notas de la diapositiva \(option + 1)", comment: "Slide notes title")
        }
    }

    /// Resuelve el anchor de diapositiva para visor indexable (PDFKit) usando el índice capturado de forma estable.
    public static func pdfSlideAnchor(forTargetSlideIndex targetIndex: Int) -> String {
        "slide_\(max(0, targetIndex) + 1)"
    }
}

/// Modela el ciclo de vida y las transiciones de estado del panel de notas de presentación.
public struct PresentationNotesSession: Equatable, Sendable {
    public var isSheetPresented: Bool
    public var pdfTargetSlideIndex: Int
    public var quickLookNoteOption: Int

    public init(
        isSheetPresented: Bool = false,
        pdfTargetSlideIndex: Int = 0,
        quickLookNoteOption: Int = PresentationNotesCoordinator.generalNoteOption
    ) {
        self.isSheetPresented = isSheetPresented
        self.pdfTargetSlideIndex = pdfTargetSlideIndex
        self.quickLookNoteOption = quickLookNoteOption
    }

    /// Apertura del panel: en QuickLook SIEMPRE inicia en general (-1) sin importar totalSlides.
    /// En PDFKit captura y fija de forma inmutable el slide actual para evitar desvíos en background.
    public mutating func open(isIndexableNavigationSupported: Bool, currentSlideIndex: Int) {
        if isIndexableNavigationSupported {
            pdfTargetSlideIndex = max(0, currentSlideIndex)
        } else {
            quickLookNoteOption = -1
        }
        isSheetPresented = true
    }

    /// Cierre del panel: restablece el destino a la nota general (-1).
    public mutating func close() {
        isSheetPresented = false
        quickLookNoteOption = -1
    }

    /// Selección explícita del usuario.
    public mutating func selectOption(_ option: Int) {
        quickLookNoteOption = option
    }

    /// Anchor efectivo para QuickLook.
    public func quickLookAnchor(totalSlides: Int) -> String {
        PresentationNotesCoordinator.quickLookAnchor(forOption: quickLookNoteOption, totalSlides: totalSlides)
    }

    /// Título efectivo para QuickLook.
    public func quickLookTitle(totalSlides: Int) -> String {
        PresentationNotesCoordinator.quickLookTitle(forOption: quickLookNoteOption, totalSlides: totalSlides)
    }

    /// Anchor efectivo para PDFKit basado en el target capturado.
    public func pdfAnchor() -> String {
        PresentationNotesCoordinator.pdfSlideAnchor(forTargetSlideIndex: pdfTargetSlideIndex)
    }
}
