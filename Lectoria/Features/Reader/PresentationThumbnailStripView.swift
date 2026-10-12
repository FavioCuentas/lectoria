import SwiftUI
import PDFKit

// MARK: - PresentationThumbnailStripView

/// Tira navegadora de miniaturas de diapositivas adaptativa inspirada en la interfaz de Apple Keynote.
///
/// Genera miniaturas PDF mediante `PDFDocument` y muestra tarjetas numeradas para QuickLook;
/// resalta la diapositiva activa y realiza autoscroll suave al cambiar de slide.
struct PresentationThumbnailStripView: View {
    let pdfDocument: PDFDocument?
    let fileURL: URL?
    let totalSlides: Int
    @Binding var currentSlideIndex: Int
    let isVertical: Bool
    let slidesWithNotesOrAnnotations: Set<Int>
    let canNavigate: Bool
    let onSelectSlide: (Int) -> Void

    @Environment(ThemeManager.self) private var themeManager

    init(
        pdfDocument: PDFDocument? = nil,
        fileURL: URL? = nil,
        totalSlides: Int,
        currentSlideIndex: Binding<Int>,
        isVertical: Bool,
        slidesWithNotesOrAnnotations: Set<Int> = [],
        canNavigate: Bool = true,
        onSelectSlide: @escaping (Int) -> Void
    ) {
        self.pdfDocument = pdfDocument
        self.fileURL = fileURL
        self.totalSlides = totalSlides
        self._currentSlideIndex = currentSlideIndex
        self.isVertical = isVertical
        self.slidesWithNotesOrAnnotations = slidesWithNotesOrAnnotations
        self.canNavigate = canNavigate
        self.onSelectSlide = onSelectSlide
    }

    var body: some View {
        let theme = themeManager.currentTheme

        Group {
            if totalSlides <= 0 {
                emptyStateView(theme: theme)
            } else if isVertical {
                // Tira lateral vertical (iPad / Mac / Pantallas anchas / iPhone Drawer)
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: AppSpacing.sm) {
                            if !canNavigate {
                                quickLookNotice(theme: theme)
                            }

                            ForEach(0..<totalSlides, id: \.self) { index in
                                thumbnailCell(index: index, theme: theme)
                                    .id(index)
                            }
                        }
                        .padding(AppSpacing.xs)
                    }
                    .onChange(of: currentSlideIndex) { _, newIndex in
                        guard canNavigate else { return }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
                .frame(width: 104)
                .background(AppColor.surface(for: theme))
            } else {
                // Tira horizontal inferior
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: AppSpacing.xs) {
                            ForEach(0..<totalSlides, id: \.self) { index in
                                thumbnailCell(index: index, theme: theme)
                                    .id(index)
                            }
                        }
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, AppSpacing.xxs)
                    }
                    .onChange(of: currentSlideIndex) { _, newIndex in
                        guard canNavigate else { return }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
                .frame(height: 72)
                .background(AppColor.surface(for: theme))
            }
        }
    }

    // MARK: - Empty & QuickLook Views

    private func emptyStateView(theme: AppTheme) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Image(systemName: "rectangle.on.rectangle.slash")
                .font(.system(size: 24))
                .foregroundStyle(AppColor.textTertiary(for: theme))

            Text(String(localized: "Sin diapositivas", comment: "Empty presentation strip title"))
                .font(AppTypography.captionBold)
                .foregroundStyle(AppColor.textSecondary(for: theme))
                .multilineTextAlignment(.center)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "No hay diapositivas disponibles", comment: "Empty strip accessibility"))
    }

    private func quickLookNotice(theme: AppTheme) -> some View {
        VStack(spacing: 2) {
            Image(systemName: "hand.draw")
                .font(.system(size: 11))
                .foregroundStyle(AppColor.accent(for: theme))

            Text(String(localized: "Desliza en la diapositiva", comment: "QuickLook swipe notice"))
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(AppColor.textSecondary(for: theme))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity)
        .background(AppColor.surfaceSecondary(for: theme))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xs))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Navegación por deslizamiento. Desliza en la diapositiva principal para cambiar de página.", comment: "QuickLook notice accessibility"))
    }

    // MARK: - Thumbnail Cell

    private func thumbnailCell(index: Int, theme: AppTheme) -> some View {
        let isSelected = canNavigate && (index == currentSlideIndex)
        let hasNotes = slidesWithNotesOrAnnotations.contains(index)
        let selectedLabel = isSelected ? String(localized: ", seleccionada", comment: "Selected slide") : ""
        let notesLabel = hasNotes ? String(localized: ", contiene notas", comment: "Slide has notes") : ""

        let cellContent = VStack(spacing: 2) {
            ZStack(alignment: .bottomTrailing) {
                // Miniatura real renderizada o placeholder visual
                RealThumbnailView(pdfDocument: pdfDocument, fileURL: fileURL, pageIndex: index, theme: theme)
                    .frame(width: isVertical ? 88 : 76, height: isVertical ? 54 : 46)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.xs))

                // Indicador discreto de notas/anotaciones guardadas en la diapositiva
                if hasNotes {
                    VStack {
                        HStack {
                            Circle()
                                .fill(AppColor.accent(for: theme))
                                .frame(width: 8, height: 8)
                                .shadow(radius: 1)
                                .padding(4)
                            Spacer()
                        }
                        Spacer()
                    }
                }

                Text("\(index + 1)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(isSelected ? .white : AppColor.textSecondary(for: theme))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(isSelected ? AppColor.accent(for: theme) : AppColor.surface(for: theme).opacity(0.85))
                    .clipShape(Capsule())
                    .padding(3)
            }
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.xs)
                    .stroke(
                        isSelected ? AppColor.accent(for: theme) : AppColor.border(for: theme),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .frame(width: isVertical ? 88 : 80)

        return Group {
            if canNavigate {
                Button {
                    onSelectSlide(index)
                } label: {
                    cellContent
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Diapositiva \(index + 1) de \(totalSlides)\(selectedLabel)\(notesLabel)")
                .accessibilityHint(String(localized: "Toca dos veces para mostrar esta diapositiva", comment: "Thumbnail jump hint"))
            } else {
                cellContent
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Diapositiva \(index + 1) de \(totalSlides)\(selectedLabel)\(notesLabel)")
                    .accessibilityHint(String(localized: "Vista previa QuickLook. Navega deslizando directamente en la pantalla.", comment: "Thumbnail non-navigable hint"))
            }
        }
    }
}

// MARK: - RealThumbnailView

/// Estado de carga de una miniatura individual.
private enum ThumbnailState: Equatable {
    case loading
    case loaded
    case unavailable
    case error(String)
}

/// Muestra la miniatura de una página PDF o una tarjeta sin imagen para QuickLook.
private struct RealThumbnailView: View {
    let pdfDocument: PDFDocument?
    let fileURL: URL?
    let pageIndex: Int
    let theme: AppTheme

    @State private var thumbnailImage: UIImage? = nil
    @State private var state: ThumbnailState = .loading
    @State private var retryID: Int = 0

    var body: some View {
        ZStack {
            switch state {
            case .loading:
                Color.gray.opacity(0.12)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.6)
                            .tint(AppColor.accent(for: theme))
                    )
                    .accessibilityLabel(String(localized: "Cargando miniatura de diapositiva \(pageIndex + 1)", comment: "Thumbnail loading accessibility"))

            case .loaded:
                if let image = thumbnailImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .accessibilityLabel(String(localized: "Miniatura de diapositiva \(pageIndex + 1)", comment: "Thumbnail loaded accessibility"))
                }

            case .unavailable:
                Color.gray.opacity(0.12)
                    .overlay(
                        Image(systemName: "rectangle.on.rectangle")
                            .foregroundStyle(AppColor.textTertiary(for: theme))
                    )
                    .accessibilityLabel("Diapositiva \(pageIndex + 1), sin miniatura disponible")

            case .error:
                Color.gray.opacity(0.15)
                    .overlay(
                        VStack(spacing: 2) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 14))
                                .foregroundStyle(AppColor.warning(for: theme))
                            Text(String(localized: "Reintentar", comment: "Thumbnail retry label"))
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(AppColor.textSecondary(for: theme))
                        }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        retryID += 1
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(String(localized: "Error al cargar la miniatura de la diapositiva \(pageIndex + 1). Toca dos veces para reintentar.", comment: "Thumbnail error accessibility"))
            }
        }
        .task(id: "\(pdfDocument.map { String(describing: ObjectIdentifier($0)) } ?? "none")_\(fileURL?.absoluteString ?? "none")_\(pageIndex)_\(retryID)") {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        state = .loading
        thumbnailImage = nil
        guard PresentationThumbnailPolicy.canRenderSlide(hasPDFDocument: pdfDocument != nil) else {
            state = .unavailable
            return
        }
        let size = CGSize(width: 160, height: 100)

        if let doc = pdfDocument {
            guard pageIndex >= 0 && pageIndex < doc.pageCount else {
                self.state = .error("Índice de página fuera de rango")
                return
            }
            if let page = doc.page(at: pageIndex) {
                let image = page.thumbnail(of: size, for: .mediaBox)
                self.thumbnailImage = image
                self.state = .loaded
            } else {
                self.state = .error("No se pudo obtener la página del documento")
            }
            return
        }

        self.state = .error("Sin archivo disponible")
    }
}

/// QuickLook document thumbnails do not identify individual slides.
enum PresentationThumbnailPolicy {
    static func canRenderSlide(hasPDFDocument: Bool) -> Bool {
        hasPDFDocument
    }
}
