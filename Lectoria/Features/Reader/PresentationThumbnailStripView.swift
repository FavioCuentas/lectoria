import SwiftUI

// MARK: - PresentationThumbnailStripView

/// Tira navegadora de miniaturas de diapositivas adaptativa inspirada en la interfaz de Apple Keynote.
///
/// Soporta modo de tira horizontal (para iPhone en orientación vertical) y barra lateral vertical (para iPad).
/// Muestra el número de cada diapositiva y resalta la activa.
struct PresentationThumbnailStripView: View {
    let totalSlides: Int
    @Binding var currentSlideIndex: Int
    let isVertical: Bool
    let onSelectSlide: (Int) -> Void

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        let theme = themeManager.currentTheme

        Group {
            if isVertical {
                // Tira lateral vertical (iPad / Horizontal)
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
                        withAnimation {
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
                        withAnimation {
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
                    RoundedRectangle(cornerRadius: AppRadius.xs)
                        .fill(AppColor.surfaceSecondary(for: theme))
                        .aspectRatio(16/9, contentMode: .fit)

                    Text("\(index + 1)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(isSelected ? .white : AppColor.textSecondary(for: theme))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(isSelected ? AppColor.accent(for: theme) : AppColor.surface(for: theme).opacity(0.8))
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
