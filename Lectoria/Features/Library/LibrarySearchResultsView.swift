import SwiftUI

// MARK: - LibrarySearchResultsView

/// Resultados de la búsqueda global en la Biblioteca, en tres grupos:
/// títulos y autores, coincidencias dentro de los documentos, y notas y destacados.
struct LibrarySearchResultsView: View {
    let results: GlobalSearchResults
    let publications: [UUID: PublicationRecord]
    let progress: [UUID: Double]
    let pendingIndexCount: Int
    let isSearching: Bool
    let theme: AppTheme
    let onOpenPublication: (PublicationRecord) -> Void
    let onOpenHit: (PublicationRecord, ContentHit) -> Void
    let onOpenAnnotation: (PublicationRecord, AnnotationHit) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.lg) {
                if results.isEmpty && !isSearching {
                    emptyState
                }

                if !results.titleMatches.isEmpty {
                    section(String(localized: "Títulos y autores", comment: "Library search: titles section")) {
                        ForEach(results.titleMatches, id: \.self) { id in
                            if let record = publications[id] {
                                PublicationCard(publication: record, style: .list, progress: progress[id] ?? 0) {
                                    onOpenPublication(record)
                                }
                            }
                        }
                    }
                }

                if !results.documents.isEmpty {
                    section(String(localized: "Dentro de documentos", comment: "Library search: content section")) {
                        ForEach(results.documents, id: \.publicationID) { document in
                            if let record = publications[document.publicationID] {
                                documentGroup(document, record: record)
                            }
                        }
                    }
                }

                if !results.annotations.isEmpty {
                    section(String(localized: "Notas y destacados", comment: "Library search: annotations section")) {
                        VStack(spacing: 0) {
                            ForEach(Array(results.annotations.enumerated()), id: \.element.id) { index, annotation in
                                if let record = publications[annotation.publicationID] {
                                    if index > 0 { Divider() }
                                    annotationRow(annotation, record: record)
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .background(AppColor.surface(for: theme))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    }
                }

                if pendingIndexCount > 0 {
                    Label(
                        String(localized: "Indexando \(pendingIndexCount) documentos… algunos resultados pueden faltar",
                               comment: "Library search: indexing in progress footer"),
                        systemImage: "hourglass"
                    )
                    .font(AppTypography.footnote)
                    .foregroundStyle(AppColor.textSecondary(for: theme))
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, AppSpacing.md)
        }
        .overlay(alignment: .top) {
            if isSearching && results.isEmpty {
                ProgressView()
                    .tint(AppColor.accent(for: theme))
                    .padding(.top, AppSpacing.xxl)
            }
        }
    }

    // MARK: - Piezas

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.title)
                .foregroundStyle(AppColor.textPrimary(for: theme))
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private func documentGroup(_ document: DocumentHits, record: PublicationRecord) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                onOpenPublication(record)
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: record.publicationType.systemImage)
                        .foregroundStyle(AppColor.accent(for: theme))
                        .frame(width: 24)
                    Text(record.title)
                        .font(AppTypography.bodyBold)
                        .foregroundStyle(AppColor.textPrimary(for: theme))
                        .lineLimit(1)
                    Spacer(minLength: AppSpacing.sm)
                    Text(document.totalMatches == 1
                         ? String(localized: "1 coincidencia", comment: "Library search: one match")
                         : String(localized: "\(document.totalMatches) coincidencias", comment: "Library search: N matches"))
                        .font(AppTypography.footnote)
                        .monospacedDigit()
                        .foregroundStyle(AppColor.textSecondary(for: theme))
                }
                .padding(.vertical, AppSpacing.sm)
            }
            .buttonStyle(.plain)

            ForEach(Array(document.hits.enumerated()), id: \.offset) { _, hit in
                Divider()
                Button {
                    onOpenHit(record, hit)
                } label: {
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text(hit.label)
                            .font(AppTypography.footnote.weight(.semibold))
                            .foregroundStyle(AppColor.accent(for: theme))
                        Text(Self.highlightedSnippet(hit.snippet))
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColor.textPrimary(for: theme))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, AppSpacing.sm)
                    .padding(.leading, 24 + AppSpacing.sm)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .background(AppColor.surface(for: theme))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
    }

    private func annotationRow(_ annotation: AnnotationHit, record: PublicationRecord) -> some View {
        Button {
            onOpenAnnotation(record, annotation)
        } label: {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: annotation.kind == .note ? "note.text" : "highlighter")
                    .foregroundStyle(AppColor.accent(for: theme))
                    .frame(width: 24)
                    .accessibilityLabel(annotation.kind == .note
                                        ? String(localized: "Nota", comment: "Annotation kind: note")
                                        : String(localized: "Destacado", comment: "Annotation kind: highlight"))
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(annotation.text)
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColor.textPrimary(for: theme))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(record.title)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColor.textSecondary(for: theme))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, AppSpacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(AppColor.textTertiary(for: theme))
            Text(String(localized: "No hay resultados", comment: "Library search: no results"))
                .font(AppTypography.callout)
                .foregroundStyle(AppColor.textSecondary(for: theme))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AppSpacing.xxxl)
    }

    /// Convierte el fragmento de FTS5 (`…texto [[palabra]] texto…`) en texto con la palabra en negrita.
    static func highlightedSnippet(_ snippet: String) -> AttributedString {
        var result = AttributedString()
        var remaining = Substring(snippet)
        while let open = remaining.range(of: "[["), let close = remaining.range(of: "]]", range: open.upperBound..<remaining.endIndex) {
            result += AttributedString(String(remaining[..<open.lowerBound]))
            var bold = AttributedString(String(remaining[open.upperBound..<close.lowerBound]))
            bold.inlinePresentationIntent = .stronglyEmphasized
            result += bold
            remaining = remaining[close.upperBound...]
        }
        result += AttributedString(String(remaining))
        return result
    }
}
