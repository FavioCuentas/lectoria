import Foundation

// MARK: - SamplePPTXGenerator

/// Generador autónomo de un archivo `.pptx` de demostración para Lectoria.
///
/// Crea en memoria un archivo ZIP valido con estructura Open XML (diapositivas,
/// títulos, cuerpo, notas del presentador y metadatos Dublin Core).
struct SamplePPTXGenerator {

    /// Crea el Data binario del archivo `.pptx` de demostración.
    static func createSamplePPTXData() -> Data {
        let contentTypes = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
  <Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
  <Override PartName="/ppt/slides/slide2.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
  <Override PartName="/ppt/slides/slide3.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
  <Override PartName="/ppt/notesSlides/notesSlide2.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.notesSlide+xml"/>
  <Override PartName="/ppt/notesSlides/notesSlide3.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.notesSlide+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
</Types>
"""

        let rels = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
</Relationships>
"""

        let coreXML = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <dc:title>Presentación Demo Lectoria</dc:title>
  <dc:creator>Equipo Lectoria</dc:creator>
</cp:coreProperties>
"""

        let presentationXML = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <p:sldIdLst>
    <p:sldId id="256" r:id="rId1"/>
    <p:sldId id="257" r:id="rId2"/>
    <p:sldId id="258" r:id="rId3"/>
  </p:sldIdLst>
</p:presentation>
"""

        let presentationRels = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide2.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide3.xml"/>
</Relationships>
"""

        let slide1 = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:sp>
        <p:txBody>
          <a:p><a:t>Introducción a Lectoria IA</a:t></a:p>
          <a:p><a:t>Módulo de Inteligencia Artificial para Lectura de Presentaciones PPTX</a:t></a:p>
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
</p:sld>
"""

        let slide2 = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:sp>
        <p:txBody>
          <a:p><a:t>Funcionalidades de Lectura y Análisis</a:t></a:p>
          <a:p><a:t>• Explicaciones detalladas con Inteligencia Artificial</a:t></a:p>
          <a:p><a:t>• Diccionario de términos y traducción multilingüe</a:t></a:p>
          <a:p><a:t>• Destacados clasificados por colores y notas de estudio</a:t></a:p>
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
</p:sld>
"""

        let notes2 = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:notes xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:sp>
        <p:txBody>
          <a:p><a:t>Revisar las notas de la diapositiva y la traducción al inglés en vivo.</a:t></a:p>
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
</p:notes>
"""

        let slide3 = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:sp>
        <p:txBody>
          <a:p><a:t>Resumen y Conclusiones</a:t></a:p>
          <a:p><a:t>• Compatibilidad nativa con formatos PPTX y PPT</a:t></a:p>
          <a:p><a:t>• Rendimiento optimizado en dispositivos iOS (ARM64)</a:t></a:p>
          <a:p><a:t>• Marcadores y sincronización de progreso en tiempo real</a:t></a:p>
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
</p:sld>
"""

        let notes3 = """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:notes xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:sp>
        <p:txBody>
          <a:p><a:t>Mencionar que las notas del presentador se muestran automáticamente en el visor.</a:t></a:p>
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
</p:notes>
"""

        let files: [(String, String)] = [
            ("[Content_Types].xml", contentTypes),
            ("_rels/.rels", rels),
            ("docProps/core.xml", coreXML),
            ("ppt/presentation.xml", presentationXML),
            ("ppt/_rels/presentation.xml.rels", presentationRels),
            ("ppt/slides/slide1.xml", slide1),
            ("ppt/slides/slide2.xml", slide2),
            ("ppt/slides/slide3.xml", slide3),
            ("ppt/notesSlides/notesSlide2.xml", notes2),
            ("ppt/notesSlides/notesSlide3.xml", notes3)
        ]

        return buildStoredZip(files: files)
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

            // Local file header
            var localHeader = Data()
            localHeader.append(contentsOf: [0x50, 0x4b, 0x03, 0x04]) // Signature
            localHeader.append(contentsOf: [0x14, 0x00]) // Version needed (2.0)
            localHeader.append(contentsOf: [0x00, 0x00]) // General purpose flag
            localHeader.append(contentsOf: [0x00, 0x00]) // Compression (0 = STORED)
            localHeader.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // Modification time/date
            localHeader.append(contentsOf: withUnsafeBytes(of: crc.littleEndian) { Array($0) })
            localHeader.append(contentsOf: withUnsafeBytes(of: UInt32(payload.count).littleEndian) { Array($0) })
            localHeader.append(contentsOf: withUnsafeBytes(of: UInt32(payload.count).littleEndian) { Array($0) })
            localHeader.append(contentsOf: withUnsafeBytes(of: UInt16(pathData.count).littleEndian) { Array($0) })
            localHeader.append(contentsOf: [0x00, 0x00]) // Extra field length

            archive.append(localHeader)
            archive.append(pathData)
            archive.append(payload)

            // Central directory header
            var cdHeader = Data()
            cdHeader.append(contentsOf: [0x50, 0x4b, 0x01, 0x02]) // Signature
            cdHeader.append(contentsOf: [0x14, 0x00]) // Version made by
            cdHeader.append(contentsOf: [0x14, 0x00]) // Version needed
            cdHeader.append(contentsOf: [0x00, 0x00]) // Flags
            cdHeader.append(contentsOf: [0x00, 0x00]) // Compression
            cdHeader.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // Time/date
            cdHeader.append(contentsOf: withUnsafeBytes(of: crc.littleEndian) { Array($0) })
            cdHeader.append(contentsOf: withUnsafeBytes(of: UInt32(payload.count).littleEndian) { Array($0) })
            cdHeader.append(contentsOf: withUnsafeBytes(of: UInt32(payload.count).littleEndian) { Array($0) })
            cdHeader.append(contentsOf: withUnsafeBytes(of: UInt16(pathData.count).littleEndian) { Array($0) })
            cdHeader.append(contentsOf: [0x00, 0x00]) // Extra length
            cdHeader.append(contentsOf: [0x00, 0x00]) // Comment length
            cdHeader.append(contentsOf: [0x00, 0x00]) // Disk number
            cdHeader.append(contentsOf: [0x00, 0x00]) // Internal attrs
            cdHeader.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // External attrs
            cdHeader.append(contentsOf: withUnsafeBytes(of: offset.littleEndian) { Array($0) })
            cdHeader.append(pathData)

            centralDirectory.append(cdHeader)
            entriesCount += 1
        }

        let cdOffset = UInt32(archive.count)
        let cdSize = UInt32(centralDirectory.count)

        archive.append(centralDirectory)

        // End of central directory record
        var eocd = Data()
        eocd.append(contentsOf: [0x50, 0x4b, 0x05, 0x06]) // Signature
        eocd.append(contentsOf: [0x00, 0x00]) // Disk number
        eocd.append(contentsOf: [0x00, 0x00]) // Disk start
        eocd.append(contentsOf: withUnsafeBytes(of: entriesCount.littleEndian) { Array($0) })
        eocd.append(contentsOf: withUnsafeBytes(of: entriesCount.littleEndian) { Array($0) })
        eocd.append(contentsOf: withUnsafeBytes(of: cdSize.littleEndian) { Array($0) })
        eocd.append(contentsOf: withUnsafeBytes(of: cdOffset.littleEndian) { Array($0) })
        eocd.append(contentsOf: [0x00, 0x00]) // Comment length

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
