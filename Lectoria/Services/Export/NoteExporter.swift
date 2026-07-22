import Foundation
import UIKit

// MARK: - NoteExportFormat

public enum NoteExportFormat: String, CaseIterable, Identifiable, Sendable {
    case pdf
    case docx
    case txt
    case markdown

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .pdf: "Documento PDF (.pdf)"
        case .docx: "Documento Word (.docx)"
        case .txt: "Texto Plano (.txt)"
        case .markdown: "Markdown (.md)"
        }
    }

    public var fileExtension: String {
        switch self {
        case .pdf: "pdf"
        case .docx: "docx"
        case .txt: "txt"
        case .markdown: "md"
        }
    }

    public var systemImage: String {
        switch self {
        case .pdf: "doc.richtext"
        case .docx: "doc.text.fill"
        case .txt: "doc.text"
        case .markdown: "text.document"
        }
    }
}

// MARK: - NoteExportData

public struct NoteExportData: Sendable {
    public let publication: PublicationRecord
    public let highlights: [Highlight]
    public let notes: [Note]

    public init(publication: PublicationRecord, highlights: [Highlight], notes: [Note]) {
        self.publication = publication
        self.highlights = highlights
        self.notes = notes
    }
}

// MARK: - NoteExporter

@MainActor
public final class NoteExporter {

    /// Exporta las anotaciones agrupadas a un archivo local temporal en el formato especificado.
    /// - Parameters:
    ///   - exportData: Lista de publicaciones con sus destacados y notas.
    ///   - format: Formato de salida (.pdf, .docx, .txt, .markdown).
    /// - Returns: URL local del archivo generado.
    public static func export(data exportData: [NoteExportData], format: NoteExportFormat) throws -> URL {
        let fileName = "Lectoria_Notas_\(formattedDateForFileName()).\(format.fileExtension)"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        switch format {
        case .txt:
            let content = generateTXTContent(data: exportData)
            try content.write(to: fileURL, atomically: true, encoding: .utf8)

        case .markdown:
            let content = generateMarkdownContent(data: exportData)
            try content.write(to: fileURL, atomically: true, encoding: .utf8)

        case .pdf:
            let pdfData = generatePDFData(data: exportData)
            try pdfData.write(to: fileURL)

        case .docx:
            let docxData = generateDOCXData(data: exportData)
            try docxData.write(to: fileURL)
        }

        return fileURL
    }

    // MARK: - Plain Text (.txt) Generator

    private static func generateTXTContent(data: [NoteExportData]) -> String {
        var text = ""
        text += "===========================================================\n"
        text += "           LECTORIA - NOTAS Y DESTACADOS                   \n"
        text += "===========================================================\n"
        text += "Fecha de exportación: \(currentFormattedDate())\n\n"

        for item in data {
            guard !item.highlights.isEmpty || !item.notes.isEmpty else { continue }

            text += "-----------------------------------------------------------\n"
            text += "DOCUMENTO: \(item.publication.title.uppercased())\n"
            if let author = item.publication.author, !author.isEmpty {
                text += "Autor: \(author)\n"
            }
            text += "Tipo: \(item.publication.publicationType.displayName)\n"
            text += "-----------------------------------------------------------\n\n"

            if !item.highlights.isEmpty {
                text += "[DESTACADOS Y CONSULTAS]\n\n"
                for hl in item.highlights {
                    let catName = categoryDisplayName(hl.category)
                    text += "• [\(catName)]: \"\(hl.selectedText)\"\n"
                    if let linkedNote = item.notes.first(where: { $0.highlightID == hl.id }) {
                        text += "  - Nota: \(linkedNote.body)\n"
                        if !linkedNote.tags.isEmpty {
                            text += "  - Etiquetas: \(linkedNote.tags.map { "#\($0)" }.joined(separator: " "))\n"
                        }
                    }
                    text += "\n"
                }
            }

            let standaloneNotes = item.notes.filter { $0.highlightID == nil }
            if !standaloneNotes.isEmpty {
                text += "[NOTAS GENERALES]\n\n"
                for note in standaloneNotes {
                    text += "• \(note.body)\n"
                    if !note.tags.isEmpty {
                        text += "  - Etiquetas: \(note.tags.map { "#\($0)" }.joined(separator: " "))\n"
                    }
                    text += "\n"
                }
            }

            text += "\n"
        }

        return text
    }

    // MARK: - Markdown (.md) Generator

    private static func generateMarkdownContent(data: [NoteExportData]) -> String {
        var md = ""
        md += "# Lectoria - Notas y Destacados\n"
        md += "*Exportado el \(currentFormattedDate())*\n\n"
        md += "---\n\n"

        for item in data {
            guard !item.highlights.isEmpty || !item.notes.isEmpty else { continue }

            md += "## 📖 \(item.publication.title)\n"
            if let author = item.publication.author, !author.isEmpty {
                md += "**Autor:** *\(author)*  \n"
            }
            md += "**Formato:** \(item.publication.publicationType.displayName)\n\n"

            if !item.highlights.isEmpty {
                md += "### 💡 Destacados y Consultas IA\n\n"
                for hl in item.highlights {
                    let catName = categoryDisplayName(hl.category)
                    md += "> **[\(catName)]** \"\(hl.selectedText)\"\n"
                    if let linkedNote = item.notes.first(where: { $0.highlightID == hl.id }) {
                        md += "- 📝 **Nota:** \(linkedNote.body)\n"
                        if !linkedNote.tags.isEmpty {
                            md += "- 🏷️ **Etiquetas:** \(linkedNote.tags.map { "`#\($0)`" }.joined(separator: " "))\n"
                        }
                    }
                    md += "\n"
                }
            }

            let standaloneNotes = item.notes.filter { $0.highlightID == nil }
            if !standaloneNotes.isEmpty {
                md += "### 📝 Notas de Estudio\n\n"
                for note in standaloneNotes {
                    md += "- \(note.body)\n"
                    if !note.tags.isEmpty {
                        md += "  - 🏷️ **Etiquetas:** \(note.tags.map { "`#\($0)`" }.joined(separator: " "))\n"
                    }
                    md += "\n"
                }
            }

            md += "---\n\n"
        }

        return md
    }

    // MARK: - PDF Generator

    private static func generatePDFData(data: [NoteExportData]) -> Data {
        let pdfMetaData = [
            kCGPDFContextTitle: "Lectoria - Reporte de Anotaciones",
            kCGPDFContextAuthor: "Lectoria IA",
            kCGPDFContextCreator: "Lectoria App"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageWidth: CGFloat = 595.2 // A4 width
        let pageHeight: CGFloat = 842.0 // A4 height
        let margin: CGFloat = 40.0
        let contentWidth = pageWidth - (margin * 2)

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight), format: format)

        return renderer.pdfData { ctx in
            var currentY: CGFloat = margin

            func checkNewPage(neededHeight: CGFloat) {
                if currentY + neededHeight > pageHeight - margin {
                    ctx.beginPage()
                    currentY = margin
                    drawHeader()
                }
            }

            func drawHeader() {
                let headerText = "LECTORIA • REPORTE DE ANOTACIONES"
                let headerFont = UIFont.systemFont(ofSize: 8, weight: .bold)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: headerFont,
                    .foregroundColor: UIColor.secondaryLabel
                ]
                headerText.draw(at: CGPoint(x: margin, y: 20), withAttributes: attrs)

                let dateText = currentFormattedDate()
                let dateSize = dateText.size(withAttributes: attrs)
                dateText.draw(at: CGPoint(x: pageWidth - margin - dateSize.width, y: 20), withAttributes: attrs)

                // Divider line
                let linePath = UIBezierPath()
                linePath.move(to: CGPoint(x: margin, y: 32))
                linePath.addLine(to: CGPoint(x: pageWidth - margin, y: 32))
                UIColor.lightGray.withAlphaComponent(0.4).setStroke()
                linePath.lineWidth = 0.5
                linePath.stroke()
            }

            ctx.beginPage()
            drawHeader()
            currentY = 45

            // Main Document Title
            let mainTitleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .bold),
                .foregroundColor: UIColor(red: 0.85, green: 0.35, blue: 0.22, alpha: 1.0)
            ]
            let mainTitle = "Reporte de Notas y Destacados"
            mainTitle.draw(at: CGPoint(x: margin, y: currentY), withAttributes: mainTitleAttr)
            currentY += 32

            for item in data {
                guard !item.highlights.isEmpty || !item.notes.isEmpty else { continue }

                checkNewPage(neededHeight: 60)

                // Pub Box / Header
                let pubTitleAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14, weight: .bold),
                    .foregroundColor: UIColor.label
                ]
                let titleRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 20)
                item.publication.title.draw(in: titleRect, withAttributes: pubTitleAttr)
                currentY += 22

                if let author = item.publication.author, !author.isEmpty {
                    let authorAttr: [NSAttributedString.Key: Any] = [
                        .font: UIFont.italicSystemFont(ofSize: 11),
                        .foregroundColor: UIColor.secondaryLabel
                    ]
                    "Autor: \(author)".draw(at: CGPoint(x: margin, y: currentY), withAttributes: authorAttr)
                    currentY += 16
                }

                currentY += 10

                // Highlights
                for hl in item.highlights {
                    let catName = categoryDisplayName(hl.category)
                    let textAttr: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 11, weight: .medium),
                        .foregroundColor: UIColor.label
                    ]

                    let hlString = "• [\(catName)] \"\(hl.selectedText)\""
                    let textHeight = hlString.boundingRect(
                        with: CGSize(width: contentWidth - 10, height: .greatestFiniteMagnitude),
                        options: .usesLineFragmentOrigin,
                        attributes: textAttr,
                        context: nil
                    ).height

                    checkNewPage(neededHeight: textHeight + 20)

                    let hlRect = CGRect(x: margin + 8, y: currentY, width: contentWidth - 8, height: textHeight + 4)
                    hlString.draw(in: hlRect, withAttributes: textAttr)
                    currentY += textHeight + 8

                    if let linkedNote = item.notes.first(where: { $0.highlightID == hl.id }) {
                        let noteAttr: [NSAttributedString.Key: Any] = [
                            .font: UIFont.systemFont(ofSize: 10),
                            .foregroundColor: UIColor.darkGray
                        ]
                        let noteText = "  Nota: \(linkedNote.body)"
                        let noteHeight = noteText.boundingRect(
                            with: CGSize(width: contentWidth - 20, height: .greatestFiniteMagnitude),
                            options: .usesLineFragmentOrigin,
                            attributes: noteAttr,
                            context: nil
                        ).height

                        checkNewPage(neededHeight: noteHeight + 10)
                        noteText.draw(in: CGRect(x: margin + 16, y: currentY, width: contentWidth - 16, height: noteHeight + 4), withAttributes: noteAttr)
                        currentY += noteHeight + 6
                    }
                }

                // Standalone Notes
                let standaloneNotes = item.notes.filter { $0.highlightID == nil }
                for note in standaloneNotes {
                    let noteAttr: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 11),
                        .foregroundColor: UIColor.label
                    ]
                    let noteText = "• Nota: \(note.body)"
                    let noteHeight = noteText.boundingRect(
                        with: CGSize(width: contentWidth - 10, height: .greatestFiniteMagnitude),
                        options: .usesLineFragmentOrigin,
                        attributes: noteAttr,
                        context: nil
                    ).height

                    checkNewPage(neededHeight: noteHeight + 14)
                    noteText.draw(in: CGRect(x: margin + 8, y: currentY, width: contentWidth - 8, height: noteHeight + 4), withAttributes: noteAttr)
                    currentY += noteHeight + 8
                }

                currentY += 15
            }
        }
    }

    // MARK: - Word (.docx) Generator

    private static func generateDOCXData(data: [NoteExportData]) -> Data {
        var bodyXML = ""
        bodyXML += "<w:p><w:pPr><w:pStyle w:val=\"Heading1\"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val=\"36\"/><w:color w:val=\"D95938\"/></w:rPr><w:t>LECTORIA - REPORTE DE ANOTACIONES</w:t></w:r></w:p>"
        bodyXML += "<w:p><w:r><w:rPr><w:i/><w:color w:val=\"777777\"/></w:rPr><w:t>Exportado el \(escapeXML(currentFormattedDate()))</w:t></w:r></w:p>"
        bodyXML += "<w:p/>"

        for item in data {
            guard !item.highlights.isEmpty || !item.notes.isEmpty else { continue }

            bodyXML += "<w:p><w:pPr><w:pStyle w:val=\"Heading2\"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val=\"28\"/></w:rPr><w:t>\(escapeXML(item.publication.title))</w:t></w:r></w:p>"
            if let author = item.publication.author, !author.isEmpty {
                bodyXML += "<w:p><w:r><w:rPr><w:i/></w:rPr><w:t>Autor: \(escapeXML(author))</w:t></w:r></w:p>"
            }

            if !item.highlights.isEmpty {
                bodyXML += "<w:p><w:r><w:rPr><w:b/></w:rPr><w:t>DESTACADOS Y CONSULTAS DE IA:</w:t></w:r></w:p>"
                for hl in item.highlights {
                    let catName = categoryDisplayName(hl.category)
                    bodyXML += "<w:p><w:r><w:rPr><w:b/></w:rPr><w:t>• [\(escapeXML(catName))]: </w:t></w:r><w:r><w:rPr><w:i/></w:rPr><w:t>\"\(escapeXML(hl.selectedText))\"</w:t></w:r></w:p>"
                    if let linkedNote = item.notes.first(where: { $0.highlightID == hl.id }) {
                        bodyXML += "<w:p><w:r><w:t>    Nota: \(escapeXML(linkedNote.body))</w:t></w:r></w:p>"
                    }
                }
            }

            let standaloneNotes = item.notes.filter { $0.highlightID == nil }
            if !standaloneNotes.isEmpty {
                bodyXML += "<w:p><w:r><w:rPr><w:b/></w:rPr><w:t>NOTAS GENERALES:</w:t></w:r></w:p>"
                for note in standaloneNotes {
                    bodyXML += "<w:p><w:r><w:t>• \(escapeXML(note.body))</w:t></w:r></w:p>"
                }
            }
            bodyXML += "<w:p/>"
        }

        let documentXML = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    \(bodyXML)
  </w:body>
</w:document>
"""

        let contentTypes = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
</Types>
"""

        let rels = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
</Relationships>
"""

        let coreXML = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <dc:title>Lectoria - Reporte de Anotaciones</dc:title>
  <dc:creator>Lectoria IA</dc:creator>
</cp:coreProperties>
"""

        let files: [(String, String)] = [
            ("[Content_Types].xml", contentTypes),
            ("_rels/.rels", rels),
            ("docProps/core.xml", coreXML),
            ("word/document.xml", documentXML)
        ]

        return buildStoredZip(files: files)
    }

    // MARK: - Helpers

    private static func categoryDisplayName(_ categoryRaw: String?) -> String {
        guard let raw = categoryRaw, let cat = HighlightCategory(rawValue: raw) else {
            return "Destacado"
        }
        switch cat {
        case .mainIdea: return "Idea Principal"
        case .secondaryIdea: return "Idea Secundaria"
        case .quote: return "Cita Memorable"
        case .question: return "Duda / Pregunta"
        case .actionItem: return "Acción Pendiente"
        case .dictionary: return "Diccionario"
        case .translation: return "Traducción"
        case .ai: return "Consulta IA"
        }
    }

    private static func currentFormattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: Date())
    }

    private static func formattedDateForFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }

    private static func escapeXML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private static func buildStoredZip(files: [(String, String)]) -> Data {
        var archive = Data()
        var centralDirectory = Data()
        var entriesCount: UInt16 = 0

        for (path, content) in files {
            let pathData = Data(path.utf8)
            let payload = Data(content.utf8)
            let crc = crc32Checksum(data: payload)
            let offset = UInt32(archive.count)

            var localHeader = Data()
            localHeader.append(contentsOf: [0x50, 0x4b, 0x03, 0x04])
            localHeader.append(contentsOf: [0x14, 0x00])
            localHeader.append(contentsOf: [0x00, 0x00])
            localHeader.append(contentsOf: [0x00, 0x00])
            localHeader.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
            localHeader.append(contentsOf: withUnsafeBytes(of: crc.littleEndian) { Array($0) })
            localHeader.append(contentsOf: withUnsafeBytes(of: UInt32(payload.count).littleEndian) { Array($0) })
            localHeader.append(contentsOf: withUnsafeBytes(of: UInt32(payload.count).littleEndian) { Array($0) })
            localHeader.append(contentsOf: withUnsafeBytes(of: UInt16(pathData.count).littleEndian) { Array($0) })
            localHeader.append(contentsOf: [0x00, 0x00])

            archive.append(localHeader)
            archive.append(pathData)
            archive.append(payload)

            var cdHeader = Data()
            cdHeader.append(contentsOf: [0x50, 0x4b, 0x01, 0x02])
            cdHeader.append(contentsOf: [0x14, 0x00])
            cdHeader.append(contentsOf: [0x14, 0x00])
            cdHeader.append(contentsOf: [0x00, 0x00])
            cdHeader.append(contentsOf: [0x00, 0x00])
            cdHeader.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
            cdHeader.append(contentsOf: withUnsafeBytes(of: crc.littleEndian) { Array($0) })
            cdHeader.append(contentsOf: withUnsafeBytes(of: UInt32(payload.count).littleEndian) { Array($0) })
            cdHeader.append(contentsOf: withUnsafeBytes(of: UInt32(payload.count).littleEndian) { Array($0) })
            cdHeader.append(contentsOf: withUnsafeBytes(of: UInt16(pathData.count).littleEndian) { Array($0) })
            cdHeader.append(contentsOf: [0x00, 0x00])
            cdHeader.append(contentsOf: [0x00, 0x00])
            cdHeader.append(contentsOf: [0x00, 0x00])
            cdHeader.append(contentsOf: [0x00, 0x00])
            cdHeader.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
            cdHeader.append(contentsOf: withUnsafeBytes(of: offset.littleEndian) { Array($0) })
            cdHeader.append(pathData)

            centralDirectory.append(cdHeader)
            entriesCount += 1
        }

        let cdOffset = UInt32(archive.count)
        let cdSize = UInt32(centralDirectory.count)

        archive.append(centralDirectory)

        var eocd = Data()
        eocd.append(contentsOf: [0x50, 0x4b, 0x05, 0x06])
        eocd.append(contentsOf: [0x00, 0x00])
        eocd.append(contentsOf: [0x00, 0x00])
        eocd.append(contentsOf: withUnsafeBytes(of: entriesCount.littleEndian) { Array($0) })
        eocd.append(contentsOf: withUnsafeBytes(of: entriesCount.littleEndian) { Array($0) })
        eocd.append(contentsOf: withUnsafeBytes(of: cdSize.littleEndian) { Array($0) })
        eocd.append(contentsOf: withUnsafeBytes(of: cdOffset.littleEndian) { Array($0) })
        eocd.append(contentsOf: [0x00, 0x00])

        archive.append(eocd)
        return archive
    }

    private static func crc32Checksum(data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = (crc >> 8) ^ crc32Table[index]
        }
        return crc ^ 0xFFFFFFFF
    }

    private static let crc32Table: [UInt32] = {
        (0...255).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 {
                if (c & 1) != 0 {
                    c = 0xEDB88320 ^ (c >> 1)
                } else {
                    c = c >> 1
                }
            }
            return c
        }
    }()
}
