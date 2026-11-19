import Foundation

// MARK: - AnnotationsExporter

/// Perfil → Exportar datos: genera un Markdown con los destacados y notas de toda la biblioteca,
/// agrupados por documento (orden alfabético) y en el orden en que se crearon.
enum AnnotationsExporter {
    static func markdown(
        publications: [PublicationRecord],
        highlights: [Highlight],
        notes: [Note],
        exportedAt: Date
    ) -> String {
        var lines = ["# Mis notas de Lectoria", ""]
        let dateText = exportedAt.formatted(date: .long, time: .shortened)
        lines.append(String(localized: "Exportado el \(dateText)", comment: "Export: date line"))
        lines.append("")

        guard !highlights.isEmpty || !notes.isEmpty else {
            lines.append(String(localized: "Todavía no tienes notas ni destacados.", comment: "Export: empty"))
            return lines.joined(separator: "\n") + "\n"
        }

        let byID = Dictionary(publications.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let highlightIDs = Set(highlights.map(\.id))
        let notesByHighlight = Dictionary(grouping: notes.filter { $0.highlightID.map(highlightIDs.contains) ?? false },
                                          by: { $0.highlightID! })
        let looseNotes = notes.filter { !($0.highlightID.map(highlightIDs.contains) ?? false) }

        let documentIDs = Set(highlights.map(\.publicationID)).union(looseNotes.map(\.publicationID))
        let missingTitle = String(localized: "Documento eliminado", comment: "Export: annotations of a deleted document")
        let ordered = documentIDs.sorted { lhs, rhs in
            let left = byID[lhs]?.title ?? missingTitle
            let right = byID[rhs]?.title ?? missingTitle
            return left.localizedStandardCompare(right) == .orderedAscending
        }

        for id in ordered {
            let record = byID[id]
            var heading = "## " + (record?.title ?? missingTitle)
            if let author = record?.author, !author.isEmpty { heading += " — " + author }
            lines.append(heading)
            lines.append("")

            for highlight in highlights.filter({ $0.publicationID == id }).sorted(by: { $0.createdAt < $1.createdAt }) {
                lines.append(quote(highlight.selectedText))
                for note in (notesByHighlight[highlight.id] ?? []).sorted(by: { $0.createdAt < $1.createdAt }) {
                    lines.append("")
                    lines.append(String(localized: "Nota: \(note.body)", comment: "Export: note attached to a highlight"))
                }
                lines.append("")
            }

            let loose = looseNotes.filter { $0.publicationID == id }.sorted { $0.createdAt < $1.createdAt }
            if !loose.isEmpty {
                lines.append(String(localized: "### Notas", comment: "Export: standalone notes heading"))
                lines.append("")
                lines.append(contentsOf: loose.map { "- " + $0.body.replacingOccurrences(of: "\n", with: "\n  ") })
                lines.append("")
            }
        }
        return lines.joined(separator: "\n")
    }

    static func fileName(exportedAt: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "Lectoria-notas-\(formatter.string(from: exportedAt)).md"
    }

    /// Escribe el archivo en una carpeta temporal y devuelve su URL para compartirlo.
    static func writeFile(_ markdown: String, exportedAt: Date) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Export", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(fileName(exportedAt: exportedAt))
        try markdown.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func quote(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { "> " + $0 }
            .joined(separator: "\n")
    }
}
