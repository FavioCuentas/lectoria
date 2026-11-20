import Foundation
import os

private let logger = Logger(subsystem: "com.orvexa.Lectoria", category: "Ink")

// MARK: - InkStore

/// Trazos a mano (pluma y marcador del Pencil) de cada documento, guardados por página.
///
/// Un archivo JSON por documento en `Application Support/Ink/<id>.json` con
/// `{ "<índice de página>": "<base64 del PKDrawing>" }`. Solo local: no entra en la copia de seguridad.
actor InkStore {
    static let shared = InkStore(directory: {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Ink", isDirectory: true)
    }())

    private let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    func drawings(for publicationID: UUID) -> [Int: Data] {
        let url = fileURL(publicationID)
        guard let data = try? Data(contentsOf: url) else { return [:] }
        guard let raw = try? JSONDecoder().decode([String: String].self, from: data) else {
            logger.error("Archivo de trazos ilegible para \(publicationID.uuidString); se ignora")
            return [:]
        }
        var result: [Int: Data] = [:]
        for (key, value) in raw {
            if let page = Int(key), let drawing = Data(base64Encoded: value) { result[page] = drawing }
        }
        return result
    }

    /// Guarda el dibujo de una página; `nil` o vacío la borra. Sin páginas, se borra el archivo.
    func save(_ data: Data?, page: Int, publicationID: UUID) throws {
        var all = drawings(for: publicationID)
        if let data, !data.isEmpty { all[page] = data } else { all[page] = nil }

        let url = fileURL(publicationID)
        guard !all.isEmpty else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        let raw = Dictionary(uniqueKeysWithValues: all.map { (String($0.key), $0.value.base64EncodedString()) })
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(raw).write(to: url, options: .atomic)
    }

    func delete(publicationID: UUID) {
        try? FileManager.default.removeItem(at: fileURL(publicationID))
    }

    private func fileURL(_ publicationID: UUID) -> URL {
        directory.appendingPathComponent("\(publicationID.uuidString).json")
    }
}
