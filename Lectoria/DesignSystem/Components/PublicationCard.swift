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
    let onUpdate: (() -> Void)?
    let action: () -> Void

    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppDependencies.self) private var dependencies

    enum Style {
        case grid
        case list
    }

    init(
        publication: PublicationRecord,
        style: Style = .grid,
        progress: Double = 0,
        onUpdate: (() -> Void)? = nil,
        action: @escaping () -> Void
    ) {
        self.publication = publication
        self.style = style
        self.progress = progress
        self.onUpdate = onUpdate
        self.action = action
    }

    var body: some View {
        Group {
            switch style {
            case .grid: gridCard
            case .list: listCard
            }
        }
        .contextMenu {
            // Fijar / Desfijar
            Button {
                var updated = publication
                updated.isPinned.toggle()
                Task {
                    try? await dependencies.publicationRepository.save(updated)
                    await MainActor.run {
                        onUpdate?()
                    }
                }
            } label: {
                Label(publication.isPinned ? "Desfijar" : "Fijar al inicio",
                      systemImage: publication.isPinned ? "pin.slash" : "pin")
            }

            // Favorito / Quitar favorito
            Button {
                var updated = publication
                updated.isFavorite.toggle()
                Task {
                    try? await dependencies.publicationRepository.save(updated)
                    await MainActor.run {
                        onUpdate?()
                    }
                }
            } label: {
                Label(publication.isFavorite ? "Quitar de favoritos" : "Hacer favorito",
                      systemImage: publication.isFavorite ? "heart.slash" : "heart")
            }

            Divider()

            // Borrar
            Button(role: .destructive) {
                Task {
                    try? await dependencies.publicationRepository.delete(id: publication.id)
                    await MainActor.run {
                        onUpdate?()
                    }
                }
            } label: {
                Label("Borrar libro", systemImage: "trash")
            }
        }
    }

    // MARK: - Grid layout

    private var gridCard: some View {
        let theme = themeManager.currentTheme
        return Button(action: action) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                // Portada con dimensiones delimitadas por la celda de la cuadrícula
                GeometryReader { geometry in
                    coverView
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
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

    // MARK: - Cover

    private var coverImageURL: URL? {
        guard let path = publication.coverPath, !path.isEmpty else { return nil }
        let coversDir = CoverGenerator().coversDirectory
        let url = coversDir.appendingPathComponent(path)
        if FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        return nil
    }

    private var coverView: some View {
        let theme = themeManager.currentTheme
        return ZStack(alignment: .topTrailing) {
            Group {
                if let url = coverImageURL, let uiImage = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                } else {
                    placeholderCover(theme: theme)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.xs))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.xs)
                    .strokeBorder(AppColor.border(for: theme).opacity(0.4), lineWidth: 1)
            )

            if publication.isArchived {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(AppSpacing.xxs)
                            .background(Color.orange)
                            .clipShape(Circle())
                            .padding(AppSpacing.xs)
                            .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                    Spacer()
                }
            } else if publication.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(AppSpacing.xxs)
                    .background(AppColor.accent(for: theme))
                    .clipShape(Circle())
                    .padding(AppSpacing.xs)
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
            }
        }
    }

    private func placeholderCover(theme: AppTheme) -> some View {
        ZStack {
            // Fondo estilo papel / e-reader
            Color(uiColor: UIColor(red: 0.965, green: 0.957, blue: 0.941, alpha: 1.0))

            VStack(spacing: AppSpacing.xs) {
                Spacer()

                Image(systemName: publication.publicationType.systemImage)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(AppColor.accent(for: theme))

                Text(publication.title)
                    .font(.system(size: 11, weight: .bold, design: .serif))
                    .foregroundStyle(Color(uiColor: UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, AppSpacing.xs)

                if let author = publication.author, !author.isEmpty {
                    Text(author)
                        .font(.system(size: 9, weight: .regular, design: .serif))
                        .foregroundStyle(Color.gray)
                        .lineLimit(1)
                }

                Spacer()

                Text(publication.publicationType.displayName.uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(AppColor.accent(for: theme).opacity(0.8))
                    .padding(.bottom, AppSpacing.xs)
            }
            .padding(AppSpacing.xs)
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
