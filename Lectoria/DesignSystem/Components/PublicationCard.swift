import SwiftUI

// MARK: - PublicationCard

/// Card que muestra una publicación en la biblioteca.
///
/// Soporta dos modos de presentación: cuadrícula y lista.
/// Muestra portada (placeholder si no hay), título, autor,
/// tipo de formato y barra de progreso.
struct PublicationCard: View {
    let publication: PublicationRecord
    let style: Style
    let progress: Double
    let action: () -> Void

    @Environment(ThemeManager.self) private var themeManager

    enum Style {
        case grid
        case list
    }

    init(
        publication: PublicationRecord,
        style: Style = .grid,
        progress: Double = 0,
        action: @escaping () -> Void
    ) {
        self.publication = publication
        self.style = style
        self.progress = progress
        self.action = action
    }

    var body: some View {
        switch style {
        case .grid: gridCard
        case .list: listCard
        }
    }

    // MARK: - Grid layout

    private var gridCard: some View {
        let theme = themeManager.currentTheme
        return Button(action: action) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                // Portada placeholder
                coverView
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(publication.title)
                        .font(AppTypography.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(AppColor.textPrimary(for: theme))
                        .lineLimit(2)

                    if let author = publication.author {
                        Text(author)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColor.textSecondary(for: theme))
                            .lineLimit(1)
                    }

                    if progress > 0 {
                        ProgressPill(progress: progress)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - List layout

    private var listCard: some View {
        let theme = themeManager.currentTheme
        return Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                coverView
                    .frame(width: 50, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.xs))

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(publication.title)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColor.textPrimary(for: theme))
                        .lineLimit(1)

                    if let author = publication.author {
                        Text(author)
                            .font(AppTypography.footnote)
                            .foregroundStyle(AppColor.textSecondary(for: theme))
                            .lineLimit(1)
                    }

                    HStack(spacing: AppSpacing.sm) {
                        Label(publication.publicationType.displayName,
                              systemImage: publication.publicationType.systemImage)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColor.textTertiary(for: theme))

                        if progress > 0 {
                            ProgressPill(progress: progress, compact: true)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.textTertiary(for: theme))
            }
            .padding(.vertical, AppSpacing.sm)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Cover

    private var coverView: some View {
        let theme = themeManager.currentTheme
        return ZStack {
            RoundedRectangle(cornerRadius: AppRadius.xs)
                .fill(AppColor.surface(for: theme))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.xs)
                        .strokeBorder(AppColor.border(for: theme), lineWidth: 1)
                )

            VStack(spacing: AppSpacing.sm) {
                Spacer()
                
                Image(systemName: publication.publicationType.systemImage)
                    .font(.body)
                    .foregroundStyle(AppColor.textSecondary(for: theme))

                Text(publication.title)
                    .font(.system(size: 11, weight: .bold, design: .serif))
                    .foregroundStyle(AppColor.textPrimary(for: theme))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, AppSpacing.xs)

                Spacer()
                
                Text(publication.publicationType.displayName.uppercased())
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(AppColor.textTertiary(for: theme))
                    .padding(.bottom, AppSpacing.sm)
            }
        }
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        var parts = [publication.title]
        if let author = publication.author {
            parts.append(author)
        }
        parts.append(publication.publicationType.displayName)
        if progress > 0 {
            let percent = Int(progress * 100)
            parts.append("\(percent)%")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Previews

#Preview("Publication Cards") {
    let themeManager = ThemeManager()
    ScrollView {
        VStack(spacing: AppSpacing.xl) {
            Text("Cuadrícula")
                .font(AppTypography.title)
            LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: AppSpacing.lg) {
                PublicationCard(publication: .previewEPUB, progress: 0.45) {}
                PublicationCard(publication: .previewPDF, progress: 0.12) {}
                PublicationCard(publication: .previewTXT) {}
                PublicationCard(publication: .previewMarkdown, progress: 1.0) {}
            }

            Divider()

            Text("Lista")
                .font(AppTypography.title)
            VStack(spacing: 0) {
                PublicationCard(publication: .previewEPUB, style: .list, progress: 0.45) {}
                Divider()
                PublicationCard(publication: .previewPDF, style: .list, progress: 0.12) {}
                Divider()
                PublicationCard(publication: .previewTXT, style: .list) {}
            }
        }
        .padding()
    }
    .background(AppColor.background(for: themeManager.currentTheme))
    .environment(themeManager)
}
