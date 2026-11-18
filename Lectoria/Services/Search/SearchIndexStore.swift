import Foundation
import SQLite3
import os

private let logger = Logger(subsystem: "com.orvexa.Lectoria", category: "SearchIndex")

/// Indica a SQLite que copie el texto enlazado (el buffer de Swift no sobrevive a la llamada).
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// MARK: - Tipos

/// Fragmento de texto de un documento listo para indexar.
struct IndexChunk: Sendable, Equatable {
    /// Dónde está dentro del documento: página, href del capítulo, bloque o diapositiva.
    let locator: String
    /// Texto que se muestra en el resultado ("Página 3", "Capítulo uno"…).
    let label: String
    let text: String
}

/// Una coincidencia dentro de un fragmento. La palabra encontrada va entre `[[` y `]]`.
struct ContentHit: Sendable, Equatable {
    let publicationID: UUID
    let locator: String
    let label: String
    let snippet: String
}

/// Coincidencias de un documento: hasta 5 fragmentos (en orden del documento) y el total.
struct DocumentHits: Sendable, Equatable {
    let publicationID: UUID
    let totalMatches: Int
    let hits: [ContentHit]
}

enum SearchIndexError: Error {
    case openFailed(String)
    case statementFailed(String)
}

// MARK: - SearchIndexStore

/// Índice de contenido para la búsqueda global: una base SQLite propia con una tabla FTS5,
/// separada de SwiftData. Se puede reconstruir siempre desde los archivos.
actor SearchIndexStore {
    static let maxHitsPerDocument = 5

    private let url: URL
    nonisolated(unsafe) private var db: OpaquePointer?

    static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("SearchIndex.sqlite")
    }

    /// Abre o crea la base. Si está corrupta, la borra y la vuelve a crear una vez.
    init(url: URL) throws {
        self.url = url
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        do {
            db = try Self.openAndPrepare(url)
        } catch {
            logger.error("Índice de búsqueda ilegible, se recrea: \(String(describing: error))")
            Self.removeFiles(at: url)
            db = try Self.openAndPrepare(url)
        }
    }

    deinit {
        sqlite3_close_v2(db)
    }

    // MARK: Escritura

    func replace(publicationID: UUID, chunks: [IndexChunk]) throws {
        try exec("BEGIN IMMEDIATE")
        do {
            try deleteRows(publicationID)
            let statement = try prepare("INSERT INTO chunks(publication_id, locator, label, text) VALUES (?, ?, ?, ?)")
            defer { sqlite3_finalize(statement) }
            for chunk in chunks {
                sqlite3_reset(statement)
                bind(publicationID.uuidString, at: 1, in: statement)
                bind(chunk.locator, at: 2, in: statement)
                bind(chunk.label, at: 3, in: statement)
                bind(chunk.text, at: 4, in: statement)
                guard sqlite3_step(statement) == SQLITE_DONE else { throw lastError() }
            }
            try exec("COMMIT")
        } catch {
            try? exec("ROLLBACK")
            throw error
        }
    }

    func delete(publicationID: UUID) throws {
        try deleteRows(publicationID)
    }

    // MARK: Lectura

    func search(_ query: String, limitDocuments: Int = 50) throws -> [DocumentHits] {
        guard let expression = SearchQuery.ftsExpression(for: query) else { return [] }
        let sql = """
        SELECT rowid, publication_id, locator, label, snippet(chunks, 3, '[[', ']]', '…', 12), bm25(chunks)
        FROM chunks WHERE chunks MATCH ? ORDER BY bm25(chunks) LIMIT 2000
        """
        let statement: OpaquePointer?
        do {
            statement = try prepare(sql)
        } catch {
            logger.error("Búsqueda no preparada: \(String(describing: error))")
            return []
        }
        defer { sqlite3_finalize(statement) }
        bind(expression, at: 1, in: statement)

        struct Row { let rowid: Int64; let hit: ContentHit }
        var rowsByDocument: [UUID: [Row]] = [:]
        var bestRank: [UUID: Double] = [:]
        var order: [UUID] = []

        while true {
            let step = sqlite3_step(statement)
            if step == SQLITE_DONE { break }
            guard step == SQLITE_ROW else {
                // Una consulta que FTS5 no acepta no debe llegar al usuario como error.
                logger.error("Búsqueda interrumpida: \(String(cString: sqlite3_errmsg(self.db)))")
                break
            }
            guard let id = UUID(uuidString: text(statement, 1)) else { continue }
            let hit = ContentHit(publicationID: id, locator: text(statement, 2), label: text(statement, 3), snippet: text(statement, 4))
            if rowsByDocument[id] == nil {
                order.append(id)
                bestRank[id] = sqlite3_column_double(statement, 5)
            }
            rowsByDocument[id, default: []].append(Row(rowid: sqlite3_column_int64(statement, 0), hit: hit))
        }

        return order.prefix(limitDocuments).map { id in
            let rows = rowsByDocument[id] ?? []
            let firstInDocumentOrder = rows.sorted { $0.rowid < $1.rowid }.prefix(Self.maxHitsPerDocument).map(\.hit)
            return DocumentHits(publicationID: id, totalMatches: rows.count, hits: Array(firstInDocumentOrder))
        }
    }

    func indexedPublicationIDs() throws -> Set<UUID> {
        let statement = try prepare("SELECT DISTINCT publication_id FROM chunks")
        defer { sqlite3_finalize(statement) }
        var ids: Set<UUID> = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let id = UUID(uuidString: text(statement, 0)) { ids.insert(id) }
        }
        return ids
    }

    // MARK: - SQLite

    private static func openAndPrepare(_ url: URL) throws -> OpaquePointer? {
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &handle, flags, nil) == SQLITE_OK else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "sin conexión"
            sqlite3_close_v2(handle)
            throw SearchIndexError.openFailed(message)
        }
        let create = """
        CREATE VIRTUAL TABLE IF NOT EXISTS chunks USING fts5(
            publication_id UNINDEXED, locator UNINDEXED, label UNINDEXED, text,
            tokenize='unicode61 remove_diacritics 2'
        )
        """
        guard sqlite3_exec(handle, create, nil, nil, nil) == SQLITE_OK,
              sqlite3_exec(handle, "SELECT count(*) FROM chunks", nil, nil, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(handle))
            sqlite3_close_v2(handle)
            throw SearchIndexError.openFailed(message)
        }
        return handle
    }

    private static func removeFiles(at url: URL) {
        for suffix in ["", "-wal", "-shm", "-journal"] {
            try? FileManager.default.removeItem(atPath: url.path + suffix)
        }
    }

    private func deleteRows(_ publicationID: UUID) throws {
        let statement = try prepare("DELETE FROM chunks WHERE publication_id = ?")
        defer { sqlite3_finalize(statement) }
        bind(publicationID.uuidString, at: 1, in: statement)
        guard sqlite3_step(statement) == SQLITE_DONE else { throw lastError() }
    }

    private func exec(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw lastError() }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            sqlite3_finalize(statement)
            throw lastError()
        }
        return statement
    }

    private func bind(_ value: String, at index: Int32, in statement: OpaquePointer?) {
        sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT)
    }

    private func text(_ statement: OpaquePointer?, _ column: Int32) -> String {
        sqlite3_column_text(statement, column).map { String(cString: $0) } ?? ""
    }

    private func lastError() -> SearchIndexError {
        .statementFailed(String(cString: sqlite3_errmsg(db)))
    }
}
