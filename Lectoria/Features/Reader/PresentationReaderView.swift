import SwiftUI
import QuickLook
import PDFKit

// MARK: - PresentationReaderView

/// Vista principal de lectura de presentaciones PowerPoint (`.ppt` y `.pptx`) y PDF de diapositivas.
///
/// Integra maquetación limpia sin barras laterales redundantes en iPad, herramientas de estudio completas de Lectoría
/// (resaltado por 5 colores, diccionario, traducción e IA), modo pantalla completa e historial de navegación.
struct PresentationReaderView: View {
    let record: PublicationRecord

    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppDependencies.self) private var dependencies

    @State private var fileURL: URL?
    @State private var pdfDocument: PDFDocument? = nil
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showShareSheet = false
    @State private var sessionCoordinator: ReadingSessionCoordinator?

    // Control de navegación por páginas / diapositivas
    @State private var currentSlideIndex: Int = 0
    @State private var totalSlides: Int = 1
    @State private var lastJumpOriginIndex: Int? = nil
    @State private var showGoToPageDialog = false
    @State private var goToPageText = ""

    // Estados de interfaz adaptativa estilo Keynote
    @State private var isFullscreen = false

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
    @State private var showInlineBubble = false
    @State private var inlineBubbleTitle = ""
    @State private var inlineBubbleText = ""
    @State private var isLoadingInline = false

    var body: some View {
        let theme = themeManager.currentTheme
        let progressPercent = Double(currentSlideIndex) / Double(max(1, totalSlides - 1))

        ZStack {
            VStack(spacing: 0) {
                // 1. Barra de herramientas superior personalizada (ocultable en pantalla completa)
                if !isFullscreen {
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

                        Text(record.title)
                            .font(AppTypography.bodyBold)
                            .foregroundStyle(AppColor.textPrimary(for: theme))
                            .lineLimit(1)

                        Spacer()

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

                        if let fileURL {
                            ShareLink(item: fileURL) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(AppColor.textPrimary(for: theme))
                                    .frame(width: 36, height: 36)
                                    .background(AppColor.surfaceSecondary(for: theme))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.xs)
                    .background(AppColor.surface(for: theme))

                    Divider()
                        .background(AppColor.border(for: theme))
                }

                // 2. Área Central de Lectura (Diapositiva Central)
                ZStack(alignment: .bottom) {
                    AppColor.background(for: theme)
                        .ignoresSafeArea()

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
                            }
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
                    if let originIndex = lastJumpOriginIndex, originIndex != currentSlideIndex, !isFullscreen {
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

                // 3. Panel Inferior de Notas por Diapositiva (5 Categorías)
                if !isFullscreen {
                    PresentationNotesPanelView(
                        slideIndex: currentSlideIndex,
                        totalSlides: totalSlides,
                        existingNotes: notes,
                        onSaveNote: { text, category in
                            let newNote = Note(
                                publicationID: record.id,
                                anchor: "slide_\(currentSlideIndex + 1)",
                                body: text,
                                tags: [category.rawValue]
                            )
                            notes.append(newNote)
                        }
                    )
                }

                // 4. Barra de Navegación y Progreso Inferior estilo Keynote
                if !isFullscreen {
                    Divider()
                        .background(AppColor.border(for: theme))

                    HStack {
                        Button {
                            goToPageText = "\(currentSlideIndex + 1)"
                            showGoToPageDialog = true
                        } label: {
                            HStack(spacing: AppSpacing.xxs) {
                                Text(String(localized: "Diapositiva \(currentSlideIndex + 1) de \(totalSlides)", comment: "Slide progress label"))
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColor.textSecondary(for: theme))
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(AppColor.textTertiary(for: theme))
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Ir a número de diapositiva. Diapositiva actual \(currentSlideIndex + 1) de \(totalSlides)")

                        Spacer()

                        Button {
                            goToPageText = "\(currentSlideIndex + 1)"
                            showGoToPageDialog = true
                        } label: {
                            Text(String(format: "%.0f%%", progressPercent * 100))
                                .font(AppTypography.captionBold)
                                .foregroundStyle(AppColor.accent(for: theme))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Ir a número de diapositiva por porcentaje. Progreso actual \(Int(progressPercent * 100))%")
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.xs)

                    ProgressView(value: progressPercent, total: 1.0)
                        .tint(AppColor.accent(for: theme))
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.bottom, AppSpacing.xs)
                }
            }
            .background(
                AppColor.surface(for: theme)
                    .shadow(color: AppShadow.subtle(for: theme).color,
                            radius: AppShadow.subtle(for: theme).radius,
                            x: AppShadow.subtle(for: theme).x,
                            y: AppShadow.subtle(for: theme).y)
            )

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
            TextField(String(localized: "Número de diapositiva (1-\(totalSlides))", comment: "Slide textfield placeholder"), text: $goToPageText)
                .keyboardType(.numberPad)
            Button(String(localized: "Ir", comment: "Go to slide confirm")) {
                if let page = Int(goToPageText), page >= 1 && page <= totalSlides {
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
        .onChange(of: scenePhase) { _, newPhase in
            sessionCoordinator?.handleScenePhaseChange(newPhase)
        }
        .onDisappear {
            sessionCoordinator?.endSession()
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
                        Text(inlineBubbleText)
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

        Task {
            let token = dependencies.authService.sessionToken
            do {
                let result: String
                if action.hasPrefix("translate_") {
                    let langCode = String(action.dropFirst("translate_".count))
                    result = try await dependencies.aiService.translate(text: textToProcess, targetLanguage: langCode, sessionToken: token)
                } else {
                    switch action {
                    case "define": result = try await dependencies.aiService.explain(text: "Define el término: \(textToProcess)", sessionToken: token)
                    case "explain": result = try await dependencies.aiService.explain(text: textToProcess, sessionToken: token)
                    case "simplify": result = try await dependencies.aiService.simplify(text: textToProcess, sessionToken: token)
                    case "summarize": result = try await dependencies.aiService.summarize(text: textToProcess, sessionToken: token)
                    case "generateQuestions": result = try await dependencies.aiService.generateQuestions(text: textToProcess, sessionToken: token)
                    default: result = ""
                    }
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
            self.fileURL = validURL
            if validURL.pathExtension.lowercased() == "pdf", let pdf = PDFDocument(url: validURL) {
                self.pdfDocument = pdf
                self.totalSlides = pdf.pageCount
            } else if let parsedSlides = try? await PPTXParser.parse(url: validURL), !parsedSlides.isEmpty {
                self.totalSlides = parsedSlides.count
            }
            self.isLoading = false

            if sessionCoordinator == nil {
                let coordinator = ReadingSessionCoordinator(
                    publicationID: record.id,
                    format: record.publicationType.analyticsFormat,
                    analyticsService: dependencies.analyticsService,
                    readingSessionRepository: dependencies.readingSessionRepository
                )
                coordinator.startSession()
                self.sessionCoordinator = coordinator
            }
        } else {
            self.errorMessage = String(localized: "El archivo de la presentación no fue encontrado en el almacenamiento local.", comment: "File missing error")
            self.isLoading = false
        }
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
