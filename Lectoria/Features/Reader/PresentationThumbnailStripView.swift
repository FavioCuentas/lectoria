import SwiftUI
import PDFKit

// MARK: - PresentationThumbnailStripView

/// Tira navegadora de miniaturas de diapositivas adaptativa inspirada en la interfaz de Apple Keynote.
///
/// Genera miniaturas vectoriales reales asíncronas vía `PDFDocument` y `PresentationCacheManager`,
/// resalta la diapositiva activa y realiza autoscroll suave al cambiar de slide.
struct PresentationThumbnailStripView: View {
    let pdfDocument: PDFDocument?
    let totalSlides: Int
    @Binding var currentSlideIndex: Int
    let isVertical: Bool
    let onSelectSlide: (Int) -> Void

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        let theme = themeManager.currentTheme

        Group {
            if isVertical {
                // Tira lateral vertical (iPad / Mac / Pantallas anchas)
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: AppSpacing.sm) {
                            ForEach(0..<max(1, totalSlides), id: \.self) { index in
                                thumbnailCell(index: index, theme: theme)
                                    .id(index)
                            }
                        }
                        .padding(AppSpacing.xs)
                    }
                    .onChange(of: currentSlideIndex) { _, newIndex in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
                .frame(width: 100)
                .background(AppColor.surface(for: theme))
            } else {
                // Tira horizontal inferior (iPhone)
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: AppSpacing.xs) {
                            ForEach(0..<max(1, totalSlides), id: \.self) { index in
                                thumbnailCell(index: index, theme: theme)
                                    .id(index)
                            }
                        }
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, AppSpacing.xxs)
                    }
                    .onChange(of: currentSlideIndex) { _, newIndex in
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

    // MARK: - Thumbnail Cell

    private func thumbnailCell(index: Int, theme: AppTheme) -> some View {
        let isSelected = index == currentSlideIndex

        return Button {
            onSelectSlide(index)
        } label: {
            VStack(spacing: 2) {
                ZStack(alignment: .bottomTrailing) {
                    // Miniatura real renderizada o placeholder visual
                    RealThumbnailView(pdfDocument: pdfDocument, pageIndex: index)
                        .frame(width: isVertical ? 84 : 76, height: isVertical ? 50 : 46)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xs))

                    Text("\(index + 1)")
                        .font(.system(size: 9, weight: .bold))
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
            .frame(width: isVertical ? 84 : 80)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Diapositiva \(index + 1) de \(totalSlides)")
    }
}

// MARK: - RealThumbnailView

/// Genera y muestra la miniatura vectorial real de la diapositiva en segundo plano utilizando `PresentationCacheManager`.
private struct RealThumbnailView: View {
    let pdfDocument: PDFDocument?
    let pageIndex: Int

    @State private var thumbnailImage: UIImage? = nil

    var body: some View {
        ZStack {
            if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Color.gray.opacity(0.15)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.6)
                    )
            }
        }
        .task(id: pageIndex) {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        guard let doc = pdfDocument else { return }
        let cacheKey = "slide_thumb_\(doc.documentURL?.lastPathComponent ?? "doc")_\(pageIndex)"

        if let cached = PresentationCacheManager.shared.cachedThumbnail(for: cacheKey) {
            self.thumbnailImage = cached
            return
        }

        let size = CGSize(width: 160, height: 100)
        guard let page = doc.page(at: pageIndex) else { return }
        let image = page.thumbnail(of: size, for: .mediaBox)
        PresentationCacheManager.shared.cacheThumbnail(image, for: cacheKey)
        self.thumbnailImage = image
    }
}
