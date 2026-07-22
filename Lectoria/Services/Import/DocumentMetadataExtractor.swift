import Foundation
import PDFKit
import zlib

// MARK: - ExtractedMetadata

public struct ExtractedMetadata: Sendable {
    public let title: String
    public let author: String?
    public let language: String?

    public init(title: String, author: String? = nil, language: String? = nil) {
        self.title = title
        self.author = author
        self.language = language
    }
}

// MARK: - DocumentMetadataExtractor

/// Clase encargada de leer los archivos importados para extraer metadatos básicos como título, autor e idioma.
public final class DocumentMetadataExtractor: Sendable {
    public init() {}

    /// Extrae metadatos del archivo ubicado en la URL dada según su tipo.
    /// - Parameters:
    ///   - url: URL local del archivo.
    ///   - type: Tipo de publicación de Lectoria.
    ///   - originalFileName: Nombre de archivo original si el archivo fue renombrado temporalmente.
    /// - Returns: Una estructura `ExtractedMetadata` con los datos obtenidos o valores por defecto.
    public func extract(from url: URL, type: PublicationType, originalFileName: String? = nil) -> ExtractedMetadata {
        // Título por defecto basado en el nombre del archivo original o el actual
        let fallbackName = originalFileName ?? url.lastPathComponent
        let defaultTitle = URL(fileURLWithPath: fallbackName).deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .capitalized
        
        switch type {
        case .pdf:
            guard let pdfDoc = PDFDocument(url: url) else {
                return ExtractedMetadata(title: defaultTitle)
            }
            
            let attributes = pdfDoc.documentAttributes ?? [:]
            let titleAttr = attributes[PDFDocumentAttribute.titleAttribute] as? String
            let authorAttr = attributes[PDFDocumentAttribute.authorAttribute] as? String
            
            let title = titleAttr?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let author = authorAttr?.trimmingCharacters(in: .whitespacesAndNewlines)
            
            return ExtractedMetadata(
                title: title.isEmpty ? defaultTitle : title,
                author: author?.isEmpty == true ? nil : author
            )
            
        case .epub:
            // En Fase 2 (sin Readium ni unzipper nativo) usamos el nombre de archivo.
            // Esto se mejorará en la Fase 3 con la lectura del manifest XML (.opf) de Readium.
            return ExtractedMetadata(title: defaultTitle)
            
        case .txt, .markdown:
            do {
                // Intentamos leer el archivo como UTF-8
                let content = try String(contentsOf: url, encoding: .utf8)
                
                if type == .markdown {
                    // En Markdown, buscamos el primer encabezado H1 (# Título)
                    let lines = content.components(separatedBy: .newlines)
                    for line in lines {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.hasPrefix("#") {
                            // Validar que sea un H1 y no H2 (##)
                            let h1Content = trimmed.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.hasPrefix("##") && !h1Content.isEmpty {
                                return ExtractedMetadata(title: String(h1Content))
                            }
                        }
                    }
                }
                
                // Si no se encuentra encabezado o es TXT, usamos el defaultTitle
                return ExtractedMetadata(title: defaultTitle)
            } catch {
                // Si falla la codificación, regresamos el fallback
                return ExtractedMetadata(title: defaultTitle)
            }
            
        case .pastedText:
            return ExtractedMetadata(title: String(localized: "Texto pegado", comment: "Title for pasted text"))
            
        case .pptx:
            if let metadata = extractPPTXMetadata(from: url, defaultTitle: defaultTitle) {
                return metadata
            }
            return ExtractedMetadata(title: defaultTitle)
        }
    }

    // MARK: - PPTX Metadata Extraction Helpers

    private func extractPPTXMetadata(from url: URL, defaultTitle: String) -> ExtractedMetadata? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        var offset = 0
        
        while offset + 30 <= data.count {
            let sig0 = data[offset]
            let sig1 = data[offset + 1]
            let sig2 = data[offset + 2]
            let sig3 = data[offset + 3]
            
            guard sig0 == 0x50 && sig1 == 0x4b && sig2 == 0x03 && sig3 == 0x04 else { break }
            
            let compressionMethod = readUInt16(data, offset: offset + 8)
            let compressedSize = Int(readUInt32(data, offset: offset + 18))
            let uncompressedSize = Int(readUInt32(data, offset: offset + 22))
            let fileNameLength = Int(readUInt16(data, offset: offset + 26))
            let extraFieldLength = Int(readUInt16(data, offset: offset + 28))
            
            let fileNameStart = offset + 30
            let fileNameEnd = fileNameStart + fileNameLength
            guard fileNameEnd <= data.count else { break }
            
            let fileNameData = data.subdata(in: fileNameStart..<fileNameEnd)
            guard let fileName = String(data: fileNameData, encoding: .utf8) else {
                let nextOffset = max(fileNameEnd + extraFieldLength + compressedSize, offset + 1)
                offset = nextOffset
                continue
            }
            
            let dataStart = fileNameEnd + extraFieldLength
            let dataEnd = dataStart + compressedSize
            
            let nextOffset = max(dataEnd, offset + 30 + fileNameLength + extraFieldLength)
            defer { offset = nextOffset }
            
            guard dataEnd <= data.count && dataStart <= dataEnd else { break }
            
            if fileName == "docProps/core.xml" {
                let compressedData = data.subdata(in: dataStart..<dataEnd)
                var decompressed: Data? = nil
                if compressionMethod == 0 {
                    decompressed = compressedData
                } else if compressionMethod == 8 {
                    decompressed = decompressDeflate(compressedData, expectedSize: uncompressedSize)
                }
                
                if let xmlData = decompressed {
                    return parseCoreXML(xmlData, defaultTitle: defaultTitle)
                }
                break
            }
        }
        return nil
    }

    private func decompressDeflate(_ compressedData: Data, expectedSize: Int) -> Data? {
        guard !compressedData.isEmpty else { return Data() }

        var stream = z_stream()
        guard inflateInit2_(&stream, -15, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            return nil
        }
        defer { inflateEnd(&stream) }

        var decompressed = Data()
        let chunkCapacity = 16384
        var chunk = Data(count: chunkCapacity)

        return compressedData.withUnsafeBytes { srcPtr -> Data? in
            guard let srcBase = srcPtr.baseAddress else { return nil }
            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: srcBase.assumingMemoryBound(to: Bytef.self))
            stream.avail_in = UInt32(compressedData.count)

            while true {
                let status = chunk.withUnsafeMutableBytes { dstPtr -> Int32 in
                    guard let dstBase = dstPtr.baseAddress else { return Z_STREAM_ERROR }
                    stream.next_out = dstBase.assumingMemoryBound(to: Bytef.self)
                    stream.avail_out = UInt32(chunkCapacity)
                    return inflate(&stream, Z_NO_FLUSH)
                }

                let bytesRead = chunkCapacity - Int(stream.avail_out)
                if bytesRead > 0 {
                    decompressed.append(chunk.prefix(bytesRead))
                }

                if status == Z_STREAM_END {
                    return decompressed
                } else if status != Z_OK && status != Z_BUF_ERROR {
                    return decompressed.isEmpty ? nil : decompressed
                }

                if stream.avail_in == 0 && bytesRead == 0 {
                    return decompressed.isEmpty ? nil : decompressed
                }
            }
        }
    }

    private func readUInt16(_ data: Data, offset: Int) -> UInt16 {
        guard offset + 2 <= data.count else { return 0 }
        let b0 = UInt16(data[offset])
        let b1 = UInt16(data[offset + 1])
        return b0 | (b1 << 8)
    }

    private func readUInt32(_ data: Data, offset: Int) -> UInt32 {
        guard offset + 4 <= data.count else { return 0 }
        let b0 = UInt32(data[offset])
        let b1 = UInt32(data[offset + 1])
        let b2 = UInt32(data[offset + 2])
        let b3 = UInt32(data[offset + 3])
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    }

    private func parseCoreXML(_ data: Data, defaultTitle: String) -> ExtractedMetadata {
        let parser = CorePropertiesXMLParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        xmlParser.parse()
        
        let title = parser.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let author = parser.creator?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return ExtractedMetadata(
            title: title.isEmpty ? defaultTitle : title,
            author: author?.isEmpty == true ? nil : author
        )
    }
}

// MARK: - CorePropertiesXMLParser

private final class CorePropertiesXMLParser: NSObject, XMLParserDelegate {
    var title: String?
    var creator: String?
    
    private var currentText = ""
    private var insideTitle = false
    private var insideCreator = false
    
    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        let localName = elementName.components(separatedBy: ":").last ?? elementName
        if localName == "title" {
            insideTitle = true
            currentText = ""
        } else if localName == "creator" {
            insideCreator = true
            currentText = ""
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if insideTitle || insideCreator {
            currentText += string
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        let localName = elementName.components(separatedBy: ":").last ?? elementName
        if localName == "title" {
            insideTitle = false
            title = currentText
        } else if localName == "creator" {
            insideCreator = false
            creator = currentText
        }
    }
}
