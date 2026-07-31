import SwiftUI
import QuickLook
import PDFKit

// MARK: - PresentationReaderView

/// Vista principal de lectura de presentaciones PowerPoint (`.ppt` y `.pptx`) de alta fidelidad.
///
/// Integra la maquetación adaptativa inspirada en Apple Keynote: tira de miniaturas, slide central
/// con relación de aspecto fija, controles adaptativos, modo pantalla completa e historial de saltos.
struct PresentationReaderView: View {
    let record: PublicationRecord

    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager

    @State private var fileURL: URL?
    @State private var pdfDocument: PDFDocument? = nil
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showShareSheet = false

    // Control de navegación por páginas / diapositivas
    @State private var currentSlideIndex: Int = 0
    @State private var totalSlides: Int = 1
    @State private var lastJumpOriginIndex: Int? = nil
    @State private var showGoToPageDialog = false
    @State private var goToPageText = ""

    // Estados de interfaz adaptativa estilo Keynote
    @State private var showThumbnails = true
    @State private var isFullscreen = false

    // Sistema de notas y anotaciones
    @State private var notes: [Note] = []
    @State private var annotationPins: [SlideAnnotationPin] = []

    var body: some View {
        let theme = themeManager.currentTheme
        let progressPercent = Double(currentSlideIndex) / Double(max(1, totalSlides - 1))

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

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showThumbnails.toggle()
                        }
                    } label: {
                        Image(systemName: showThumbnails ? "rectangle.grid.1x2.fill" : "rectangle.grid.1x2")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(showThumbnails ? AppColor.accent(for: theme) : AppColor.textPrimary(for: theme))
                            .frame(width: 36, height: 36)
                            .background(AppColor.surfaceSecondary(for: theme))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(String(localized: "Alternar miniaturas", comment: "Toggle thumbnails label"))

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

            // 2. Área Central de Lectura (Con Sidebar opcional para iPad / Tira para iPhone)
            GeometryReader { geometry in
                let isWideScreen = geometry.size.width > 600

                HStack(spacing: 0) {
                    // Miniaturas verticales para pantallas anchas (iPad / Mac)
                    if showThumbnails && isWideScreen && !isFullscreen {
                        PresentationThumbnailStripView(
                            totalSlides: totalSlides,
                            currentSlideIndex: $currentSlideIndex,
                            isVertical: true,
                            onSelectSlide: { index in
                                currentSlideIndex = index
                            }
                        )

                        Divider()
                            .background(AppColor.border(for: theme))
                    }

                    // Contenedor del Slide Central
                    ZStack(alignment: .bottom) {
                        AppColor.background(for: theme)
                            .ignoresSafeArea()

                        if let pdfDoc = pdfDocument {
                            // Ruta B: PDFKit derivado de alta fidelidad
                            PDFPresentationPreviewWrapper(pdfDocument: pdfDoc, pageIndex: currentSlideIndex)
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isFullscreen.toggle()
                                    }
                                }
                        } else if let fileURL, errorMessage == nil {
                            // Ruta A: Quick Look nativo del original (.ppt / .pptx)
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
                }
            }

            // 3. Miniaturas horizontales para iPhone (cuando no es pantalla ancha y está activo)
            if showThumbnails && !isFullscreen {
                PresentationThumbnailStripView(
                    totalSlides: totalSlides,
                    currentSlideIndex: $currentSlideIndex,
                    isVertical: false,
                    onSelectSlide: { index in
                        currentSlideIndex = index
                    }
                )

                Divider()
                    .background(AppColor.border(for: theme))
            }
            // 4. Panel Inferior de Notas por Diapositiva (5 Categorías)
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

                Divider()
                    .background(AppColor.border(for: theme))
            }

            // 5. Panel Inferior Integrado (Navegación por Diapositivas & Barra de Progreso)
            if !isFullscreen {
                VStack(spacing: AppSpacing.xs) {
                    HStack {
                        Button {
                            goToPageText = "\(currentSlideIndex + 1)"
                            showGoToPageDialog = true
                        } label: {
                            HStack(spacing: AppSpacing.xxs) {
                                Text(String(localized: "Diapositiva \(currentSlideIndex + 1) de \(totalSlides)", comment: "Reader: slide progression"))
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
                .background(
                    AppColor.surface(for: theme)
                        .shadow(color: AppShadow.subtle(for: theme).color,
                                radius: AppShadow.subtle(for: theme).radius,
                                x: AppShadow.subtle(for: theme).x,
                                y: AppShadow.subtle(for: theme).y)
                )
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
