import Foundation
import zlib

// MARK: - PPTXParser

/// Parser nativo de archivos PPTX (Open XML / ZIP) en Swift puro.
///
/// Un archivo `.pptx` es un archivo ZIP que contiene:
/// - `ppt/presentation.xml` — define el orden de las diapositivas
/// - `ppt/slides/slideN.xml` — contenido de cada diapositiva
/// - `ppt/notesSlides/notesSlideN.xml` — notas del presentador
/// - `_rels/*.rels` — relaciones entre archivos internos
///
/// Este parser extrae el texto de todas las diapositivas sin dependencias externas,
/// usando `Foundation` para descomprimir el ZIP y `XMLParser` para el contenido XML.
final class PPTXParser: Sendable {

    // MARK: - Public API

    /// Parsea un archivo PPTX y retorna un array de diapositivas con su contenido textual.
    /// - Parameter url: URL del archivo `.pptx` local.
    /// - Returns: Array de `PPTXSlide` en orden.
    static func parse(url: URL) async throws -> [PPTXSlide] {
        return try await Task.detached(priority: .userInitiated) {
            try Self.parseSync(url: url)
        }.value
    }

    // MARK: - Implementation

    private static func parseSync(url: URL) throws -> [PPTXSlide] {
        // 1. Crear directorio temporal para descomprimir
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pptx_\(UUID().uuidString)", isDirectory: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // 2. Descomprimir el PPTX (que es un ZIP)
        try unzipFile(at: url, to: tempDir)

        // 3. Descubrir diapositivas en orden
        let slideOrder = try discoverSlideOrder(in: tempDir)

        // 4. Parsear cada diapositiva
        var slides: [PPTXSlide] = []

        for (index, slidePath) in slideOrder.enumerated() {
            let slideURL = tempDir.appendingPathComponent(slidePath)
            guard FileManager.default.fileExists(atPath: slideURL.path) else { continue }

            let slideData = try Data(contentsOf: slideURL)
            let slideContent = SlideXMLParser.parse(data: slideData)

            // Intentar cargar notas del presentador
            let noteNumber = index + 1
            let notesPath = "ppt/notesSlides/notesSlide\(noteNumber).xml"
            let notesURL = tempDir.appendingPathComponent(notesPath)
            var speakerNotes: String? = nil
            if FileManager.default.fileExists(atPath: notesURL.path),
               let notesData = try? Data(contentsOf: notesURL) {
                let notesContent = NotesXMLParser.parse(data: notesData)
                if !notesContent.isEmpty {
                    speakerNotes = notesContent
                }
            }

            let slide = PPTXSlide(
                slideNumber: index + 1,
                title: slideContent.title,
                bodyTexts: slideContent.bodyTexts,
                speakerNotes: speakerNotes
            )

            if slide.hasContent || speakerNotes != nil {
                slides.append(slide)
            }
        }

        return slides
    }

    // MARK: - ZIP Decompression

    /// Descomprime un archivo ZIP usando el comando `ditto` del sistema (disponible en macOS/iOS simulador)
    /// o usando una implementación nativa basada en `Process` para simulador / Archive para dispositivo.
    private static func unzipFile(at sourceURL: URL, to destinationURL: URL) throws {
        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        // Usar NSFileCoordinator para descomprimir con la API nativa de Foundation
        // Método robusto: copiar el archivo como .zip y usar FileManager
        let zipCopy = destinationURL.appendingPathComponent("archive.zip")
        try FileManager.default.copyItem(at: sourceURL, to: zipCopy)

        // Usar la API nativa de descompresión de iOS/macOS
        // FileManager no tiene un método directo de unzip, así que usamos
        // la técnica de renombrar a .zip y usar URLSession/Archive,
        // o más simple: usar el framework Compression con lectura manual del ZIP.
        try unzipUsingManualParser(zipURL: zipCopy, destinationURL: destinationURL)

        // Limpiar el archivo zip copiado
        try? FileManager.default.removeItem(at: zipCopy)
    }

    /// Parser manual de formato ZIP que extrae los archivos a disco.
    ///
    /// El formato ZIP tiene la siguiente estructura:
    /// - Local file headers (firma 0x04034b50)
    /// - Central directory (firma 0x02014b50)
    /// - End of central directory (firma 0x06054b50)
    private static func unzipUsingManualParser(zipURL: URL, destinationURL: URL) throws {
        let data = try Data(contentsOf: zipURL)
        var offset = 0

        while offset + 30 <= data.count {
            // Verificar firma de Local File Header (0x04034b50 en little endian: [0x50, 0x4b, 0x03, 0x04])
            let sig0 = data[offset]
            let sig1 = data[offset + 1]
            let sig2 = data[offset + 2]
            let sig3 = data[offset + 3]
            
            guard sig0 == 0x50 && sig1 == 0x4b && sig2 == 0x03 && sig3 == 0x04 else {
                break // Fin de cabezales o archivo no ZIP
            }

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

            let fileURL = destinationURL.appendingPathComponent(fileName)

            if fileName.hasSuffix("/") {
                // Directorio
                try FileManager.default.createDirectory(at: fileURL, withIntermediateDirectories: true)
            } else {
                let parentDir = fileURL.deletingLastPathComponent()
                if !FileManager.default.fileExists(atPath: parentDir.path) {
                    try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
                }

                if compressionMethod == 0 {
                    // STORED
                    let fileData = data.subdata(in: dataStart..<dataEnd)
                    try fileData.write(to: fileURL)
                } else if compressionMethod == 8 {
                    // DEFLATE
                    let compressedData = data.subdata(in: dataStart..<dataEnd)
                    if let decompressed = decompressDeflate(compressedData, expectedSize: uncompressedSize) {
                        try decompressed.write(to: fileURL)
                    }
                }
            }
        }
    }

    /// Descomprime datos con el algoritmo Deflate (raw, sin gzip header) usando el framework Compression/zlib.
    private static func decompressDeflate(_ compressedData: Data, expectedSize: Int) -> Data? {
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

    // MARK: - Slide Discovery

    /// Descubre el orden de las diapositivas leyendo las relaciones y/o el directorio de slides.
    private static func discoverSlideOrder(in tempDir: URL) throws -> [String] {
        // Intentar leer presentation.xml.rels para obtener el orden correcto
        let relsPath = "ppt/_rels/presentation.xml.rels"
        let relsURL = tempDir.appendingPathComponent(relsPath)

        var slideRelPaths: [(order: Int, path: String)] = []

        if FileManager.default.fileExists(atPath: relsURL.path),
           let relsData = try? Data(contentsOf: relsURL) {
            let relsParser = RelsXMLParser.parse(data: relsData)
            for rel in relsParser {
                if rel.type.contains("relationships/slide") && !rel.type.contains("slideLayout") && !rel.type.contains("slideMaster") {
                    let fullPath = "ppt/\(rel.target)"
                    // Extraer el número del nombre del archivo (slide1.xml, slide2.xml, etc.)
                    let number = extractSlideNumber(from: rel.target) ?? 999
                    slideRelPaths.append((order: number, path: fullPath))
                }
            }
        }

        if !slideRelPaths.isEmpty {
            return slideRelPaths.sorted { $0.order < $1.order }.map { $0.path }
        }

        // Fallback: listar archivos en ppt/slides/ ordenados numéricamente
        let slidesDir = tempDir.appendingPathComponent("ppt/slides")
        guard FileManager.default.fileExists(atPath: slidesDir.path) else {
            return []
        }

        let contents = try FileManager.default.contentsOfDirectory(atPath: slidesDir.path)
        let xmlFiles = contents.filter { $0.hasSuffix(".xml") && $0.hasPrefix("slide") }

        return xmlFiles
            .sorted { (extractSlideNumber(from: $0) ?? 999) < (extractSlideNumber(from: $1) ?? 999) }
            .map { "ppt/slides/\($0)" }
    }

    /// Extrae el número de diapositiva del nombre de archivo (e.g., "slide3.xml" → 3).
    private static func extractSlideNumber(from filename: String) -> Int? {
        let name = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        let digits = name.filter { $0.isNumber }
        return Int(digits)
    }

    // MARK: - Helpers

    private static func readUInt16(_ data: Data, offset: Int) -> UInt16 {
        guard offset + 2 <= data.count else { return 0 }
        let b0 = UInt16(data[offset])
        let b1 = UInt16(data[offset + 1])
        return b0 | (b1 << 8)
    }

    private static func readUInt32(_ data: Data, offset: Int) -> UInt32 {
        guard offset + 4 <= data.count else { return 0 }
        let b0 = UInt32(data[offset])
        let b1 = UInt32(data[offset + 1])
        let b2 = UInt32(data[offset + 2])
        let b3 = UInt32(data[offset + 3])
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    }
}

// MARK: - SlideXMLParser

/// Parser XML específico para archivos `ppt/slides/slideN.xml`.
/// Extrae los textos de los shapes organizados en título y cuerpo.
private final class SlideXMLParser: NSObject, XMLParserDelegate {
    struct Result {
        var title: String?
        var bodyTexts: [String]
    }

    private var currentText = ""
    private var allTexts: [String] = []
    private var insideText = false
    private var currentParagraph = ""
    private var titleText: String?
    private var bodyTexts: [String] = []
    private var isTitle = false
    private var insideParagraph = false

    static func parse(data: Data) -> Result {
        let parser = SlideXMLParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        xmlParser.parse()

        // La primera entrada de texto no vacía generalmente es el título
        let allClean = parser.allTexts.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        var title: String? = nil
        var body: [String] = []

        if let first = allClean.first {
            title = first
            body = Array(allClean.dropFirst())
        }

        return Result(title: title, bodyTexts: body)
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        let localName = elementName.components(separatedBy: ":").last ?? elementName

        if localName == "p" {
            // Inicio de párrafo (<a:p>)
            insideParagraph = true
            currentParagraph = ""
        } else if localName == "t" {
            // Inicio de texto (<a:t>)
            insideText = true
            currentText = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if insideText {
            currentText += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        let localName = elementName.components(separatedBy: ":").last ?? elementName

        if localName == "t" {
            insideText = false
            currentParagraph += currentText
        } else if localName == "p" {
            insideParagraph = false
            let trimmed = currentParagraph.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                allTexts.append(trimmed)
            }
        }
    }
}

// MARK: - NotesXMLParser

/// Parser XML para archivos `ppt/notesSlides/notesSlideN.xml`.
/// Extrae el texto de las notas del presentador.
private final class NotesXMLParser: NSObject, XMLParserDelegate {
    private var insideText = false
    private var currentText = ""
    private var paragraphs: [String] = []
    private var currentParagraph = ""

    static func parse(data: Data) -> String {
        let parser = NotesXMLParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        xmlParser.parse()

        // Filtrar textos genéricos como números de diapositiva
        let filtered = parser.paragraphs.filter { text in
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            // Ignorar textos puramente numéricos (números de diapositiva)
            return !trimmed.isEmpty && Int(trimmed) == nil
        }

        return filtered.joined(separator: "\n")
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        let localName = elementName.components(separatedBy: ":").last ?? elementName

        if localName == "p" {
            currentParagraph = ""
        } else if localName == "t" {
            insideText = true
            currentText = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if insideText {
            currentText += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        let localName = elementName.components(separatedBy: ":").last ?? elementName

        if localName == "t" {
            insideText = false
            currentParagraph += currentText
        } else if localName == "p" {
            let trimmed = currentParagraph.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                paragraphs.append(trimmed)
            }
        }
    }
}

// MARK: - RelsXMLParser

/// Parser para archivos `.rels` (relaciones de Open XML).
private final class RelsXMLParser: NSObject, XMLParserDelegate {
    struct Relationship {
        let type: String
        let target: String
    }

    private var relationships: [Relationship] = []

    static func parse(data: Data) -> [Relationship] {
        let parser = RelsXMLParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        xmlParser.parse()
        return parser.relationships
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        let localName = elementName.components(separatedBy: ":").last ?? elementName

        if localName == "Relationship" {
            if let type = attributes["Type"], let target = attributes["Target"] {
                relationships.append(Relationship(type: type, target: target))
            }
        }
    }
}
