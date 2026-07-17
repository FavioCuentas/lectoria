import Foundation
import SwiftData
import Observation

// MARK: - SupabaseSyncService

/// Implementación del SyncService que realiza la sincronización bidireccional
/// contra la base de datos de Supabase a través de llamadas REST (PostgREST).
@Observable
public final class SupabaseSyncService: SyncService, @unchecked Sendable {
    public private(set) var isSyncing: Bool = false
    
    public var lastSyncedAt: Date? {
        get {
            guard let token = authService.currentUser?.id else { return nil }
            let doubleVal = UserDefaults.standard.double(forKey: "lastSyncedAt_\(token)")
            return doubleVal > 0 ? Date(timeIntervalSince1970: doubleVal) : nil
        }
        set {
            guard let token = authService.currentUser?.id else { return }
            if let newValue {
                UserDefaults.standard.set(newValue.timeIntervalSince1970, forKey: "lastSyncedAt_\(token)")
            } else {
                UserDefaults.standard.removeObject(forKey: "lastSyncedAt_\(token)")
            }
        }
    }
    
    private let container: ModelContainer
    private let authService: any AuthService
    private let supabaseURL: String
    private let anonKey: String
    
    public init(
        container: ModelContainer,
        authService: any AuthService,
        supabaseURL: String,
        anonKey: String
    ) {
        self.container = container
        self.authService = authService
        self.supabaseURL = supabaseURL
        self.anonKey = anonKey
    }
    
    public func syncAll() async throws {
        guard let sessionToken = authService.sessionToken, !isSyncing else { return }
        
        await MainActor.run { isSyncing = true }
        defer {
            Task { @MainActor in isSyncing = false }
        }
        
        // 1. Procesar cola de eliminaciones locales primero
        try await processLocalDeletions(sessionToken: sessionToken)
        
        // 2. Sincronizar marcadores (Bookmarks)
        try await syncBookmarks(sessionToken: sessionToken)
        
        // 3. Sincronizar destacados (Highlights)
        try await syncHighlights(sessionToken: sessionToken)
        
        // 4. Sincronizar notas (Notes)
        try await syncNotes(sessionToken: sessionToken)
        
        // 5. Sincronizar progresos de lectura (ReadingProgress)
        try await syncReadingProgress(sessionToken: sessionToken)
        
        // 6. Actualizar timestamp de última sincronización
        lastSyncedAt = Date()
    }
    
    public func performInitialSync() async throws {
        guard authService.sessionToken != nil else { return }
        
        // Limpiar marca de tiempo para forzar una sincronización completa descendente
        lastSyncedAt = nil
        
        try await syncAll()
    }
    
    // MARK: - Local Deletions Process
    
    private func processLocalDeletions(sessionToken: String) async throws {
        let context = ModelContext(container)
        
        let descriptor = FetchDescriptor<SyncOperationModel>(
            predicate: #Predicate<SyncOperationModel> { $0.action == "delete" }
        )
        let ops = try context.fetch(descriptor)
        
        for op in ops {
            let tableName: String
            switch op.entityType {
            case "bookmark": tableName = "bookmarks"
            case "highlight": tableName = "highlights"
            case "note": tableName = "notes"
            default: continue
            }
            
            let url = URL(string: "\(supabaseURL)/rest/v1/\(tableName)?id=eq.\(op.entityID)")!
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
            
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                // Eliminación exitosa en servidor, remover de la cola local
                context.delete(op)
            }
        }
        
        try context.save()
    }
    
    // MARK: - Bookmarks Sync
    
    private func syncBookmarks(sessionToken: String) async throws {
        let context = ModelContext(container)
        
        // 1. Obtener registros locales
        let localModels = try context.fetch(FetchDescriptor<BookmarkModel>())
        
        // 2. Descargar registros remotos
        let remoteList = try await fetchRemoteRecords(tableName: "bookmarks", sessionToken: sessionToken, type: RemoteBookmark.self)
        
        // 3. Fusión bidireccional
        for remote in remoteList {
            let localMatch = localModels.first(where: { $0.id == remote.id })
            
            if let localMatch {
                if remote.updated_at > localMatch.updatedAt {
                    // Servidor es más nuevo, actualizar local
                    localMatch.title = remote.title
                    localMatch.anchor = remote.anchor
                    localMatch.updatedAt = remote.updated_at
                } else if localMatch.updatedAt > remote.updated_at {
                    // Local es más nuevo, subir a servidor
                    try await uploadRecord(tableName: "bookmarks", record: remoteFromLocal(localMatch), sessionToken: sessionToken)
                }
            } else {
                // No existe localmente, insertar
                let newBookmark = BookmarkModel(
                    id: remote.id,
                    publicationID: remote.publication_id,
                    anchor: remote.anchor,
                    title: remote.title,
                    createdAt: remote.created_at,
                    updatedAt: remote.updated_at
                )
                context.insert(newBookmark)
            }
        }
        
        // 4. Subir locales que no existen en el servidor
        let lastSync = lastSyncedAt
        for local in localModels {
            let remoteMatch = remoteList.first(where: { $0.id == local.id })
            if remoteMatch == nil {
                // Validar si es una creación nueva o si ya fue borrado remotamente
                // Si nunca se ha sincronizado o si fue modificado después del lastSync, lo subimos
                if lastSync == nil || local.updatedAt > lastSync! {
                    try await uploadRecord(tableName: "bookmarks", record: remoteFromLocal(local), sessionToken: sessionToken)
                }
            }
        }
        
        try context.save()
    }
    
    private func remoteFromLocal(_ model: BookmarkModel) -> RemoteBookmark {
        RemoteBookmark(
            id: model.id,
            publication_id: model.publicationID,
            anchor: model.anchor,
            title: model.title,
            created_at: model.createdAt,
            updated_at: model.updatedAt
        )
    }
    
    // MARK: - Highlights Sync
    
    private func syncHighlights(sessionToken: String) async throws {
        let context = ModelContext(container)
        let localModels = try context.fetch(FetchDescriptor<HighlightModel>())
        let remoteList = try await fetchRemoteRecords(tableName: "highlights", sessionToken: sessionToken, type: RemoteHighlight.self)
        
        for remote in remoteList {
            let localMatch = localModels.first(where: { $0.id == remote.id })
            
            if let localMatch {
                if remote.updated_at > localMatch.updatedAt {
                    localMatch.anchor = remote.anchor
                    localMatch.selectedText = remote.selected_text
                    localMatch.contextBefore = remote.context_before
                    localMatch.contextAfter = remote.context_after
                    localMatch.category = remote.category
                    localMatch.colorToken = remote.color_token
                    localMatch.updatedAt = remote.updated_at
                } else if localMatch.updatedAt > remote.updated_at {
                    try await uploadRecord(tableName: "highlights", record: remoteFromLocal(localMatch), sessionToken: sessionToken)
                }
            } else {
                let newHighlight = HighlightModel(
                    id: remote.id,
                    publicationID: remote.publication_id,
                    anchor: remote.anchor,
                    selectedText: remote.selected_text,
                    contextBefore: remote.context_before,
                    contextAfter: remote.context_after,
                    category: remote.category,
                    colorToken: remote.color_token,
                    createdAt: remote.created_at,
                    updatedAt: remote.updated_at
                )
                context.insert(newHighlight)
            }
        }
        
        let lastSync = lastSyncedAt
        for local in localModels {
            let remoteMatch = remoteList.first(where: { $0.id == local.id })
            if remoteMatch == nil {
                if lastSync == nil || local.updatedAt > lastSync! {
                    try await uploadRecord(tableName: "highlights", record: remoteFromLocal(local), sessionToken: sessionToken)
                }
            }
        }
        
        try context.save()
    }
    
    private func remoteFromLocal(_ model: HighlightModel) -> RemoteHighlight {
        RemoteHighlight(
            id: model.id,
            publication_id: model.publicationID,
            anchor: model.anchor,
            selected_text: model.selectedText,
            context_before: model.contextBefore,
            context_after: model.contextAfter,
            category: model.category ?? "mainIdea",
            color_token: model.colorToken,
            created_at: model.createdAt,
            updated_at: model.updatedAt
        )
    }
    
    // MARK: - Notes Sync
    
    private func syncNotes(sessionToken: String) async throws {
        let context = ModelContext(container)
        let localModels = try context.fetch(FetchDescriptor<NoteModel>())
        let remoteList = try await fetchRemoteRecords(tableName: "notes", sessionToken: sessionToken, type: RemoteNote.self)
        
        for remote in remoteList {
            let localMatch = localModels.first(where: { $0.id == remote.id })
            
            if let localMatch {
                if remote.updated_at > localMatch.updatedAt {
                    // Conflicto: Fusión inteligente o el último gana
                    if localMatch.body != remote.body && localMatch.updatedAt > (lastSyncedAt ?? .distantPast) {
                        // El usuario editó localmente y remotamente: fusionar notas
                        localMatch.body = remote.body + "\n[Conflicto offline - Cambios locales]:\n" + localMatch.body
                    } else {
                        localMatch.body = remote.body
                    }
                    localMatch.anchor = remote.anchor ?? ""
                    localMatch.tags = remote.tags
                    localMatch.updatedAt = remote.updated_at
                } else if localMatch.updatedAt > remote.updated_at {
                    try await uploadRecord(tableName: "notes", record: remoteFromLocal(localMatch), sessionToken: sessionToken)
                }
            } else {
                let newNote = NoteModel(
                    id: remote.id,
                    publicationID: remote.publication_id,
                    highlightID: remote.highlight_id,
                    anchor: remote.anchor ?? "",
                    body: remote.body,
                    tags: remote.tags,
                    createdAt: remote.created_at,
                    updatedAt: remote.updated_at
                )
                context.insert(newNote)
            }
        }
        
        let lastSync = lastSyncedAt
        for local in localModels {
            let remoteMatch = remoteList.first(where: { $0.id == local.id })
            if remoteMatch == nil {
                if lastSync == nil || local.updatedAt > lastSync! {
                    try await uploadRecord(tableName: "notes", record: remoteFromLocal(local), sessionToken: sessionToken)
                }
            }
        }
        
        try context.save()
    }
    
    private func remoteFromLocal(_ model: NoteModel) -> RemoteNote {
        RemoteNote(
            id: model.id,
            publication_id: model.publicationID,
            highlight_id: model.highlightID,
            anchor: model.anchor,
            body: model.body,
            tags: model.tags,
            created_at: model.createdAt,
            updated_at: model.updatedAt
        )
    }
    
    // MARK: - Reading Progress Sync
    
    private func syncReadingProgress(sessionToken: String) async throws {
        let context = ModelContext(container)
        let localModels = try context.fetch(FetchDescriptor<ReadingProgressModel>())
        let remoteList = try await fetchRemoteRecords(tableName: "reading_progress", sessionToken: sessionToken, type: RemoteReadingProgress.self)
        
        for remote in remoteList {
            let localMatch = localModels.first(where: { $0.id == remote.id })
            
            if let localMatch {
                if remote.updated_at > localMatch.updatedAt {
                    localMatch.locatorJSON = remote.locator_json
                    localMatch.percentage = remote.percentage
                    localMatch.pageNumber = remote.page_number
                    localMatch.chapterTitle = remote.chapter_title
                    localMatch.deviceID = remote.device_id
                    localMatch.version = remote.version
                    localMatch.updatedAt = remote.updated_at
                } else if localMatch.updatedAt > remote.updated_at {
                    try await uploadRecord(tableName: "reading_progress", record: remoteFromLocal(localMatch), sessionToken: sessionToken)
                }
            } else {
                let newProgress = ReadingProgressModel(
                    id: remote.id,
                    publicationID: remote.publication_id,
                    locatorJSON: remote.locator_json,
                    percentage: remote.percentage,
                    pageNumber: remote.page_number,
                    chapterTitle: remote.chapter_title,
                    updatedAt: remote.updated_at,
                    deviceID: remote.device_id,
                    version: remote.version
                )
                context.insert(newProgress)
            }
        }
        
        let lastSync = lastSyncedAt
        for local in localModels {
            let remoteMatch = remoteList.first(where: { $0.id == local.id })
            if remoteMatch == nil {
                if lastSync == nil || local.updatedAt > lastSync! {
                    try await uploadRecord(tableName: "reading_progress", record: remoteFromLocal(local), sessionToken: sessionToken)
                }
            }
        }
        
        try context.save()
    }
    
    private func remoteFromLocal(_ model: ReadingProgressModel) -> RemoteReadingProgress {
        RemoteReadingProgress(
            id: model.id,
            publication_id: model.publicationID,
            locator_json: model.locatorJSON,
            percentage: model.percentage,
            page_number: model.pageNumber,
            chapter_title: model.chapterTitle,
            device_id: model.deviceID,
            version: model.version,
            updated_at: model.updatedAt
        )
    }
    
    // MARK: - PostgREST HTTP Helpers
    
    private func fetchRemoteRecords<T: Decodable>(
        tableName: String,
        sessionToken: String,
        type: T.Type
    ) async throws -> [T] {
        let url = URL(string: "\(supabaseURL)/rest/v1/\(tableName)?select=*")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateStr = try container.decode(String.self)
            
            let formatters = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ",
                "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ",
                "yyyy-MM-dd'T'HH:mm:ssZZZZZ",
                "yyyy-MM-dd HH:mm:ss"
            ]
            
            for format in formatters {
                let formatter = DateFormatter()
                formatter.dateFormat = format
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                if let date = formatter.date(from: dateStr) {
                    return date
                }
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Formato de fecha inválido: \(dateStr)")
        }
        
        return try decoder.decode([T].self, from: data)
    }
    
    private func uploadRecord<T: Encodable>(
        tableName: String,
        record: T,
        sessionToken: String
    ) async throws {
        let url = URL(string: "\(supabaseURL)/rest/v1/\(tableName)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // PostgREST upsert headers
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        
        let encoder = JSONEncoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        encoder.dateEncodingStrategy = .formatted(formatter)
        
        request.httpBody = try encoder.encode(record)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}

// MARK: - PostgREST Remote Models DTOs

struct RemoteBookmark: Codable {
    let id: UUID
    let publication_id: UUID
    let anchor: String
    let title: String?
    let created_at: Date
    let updated_at: Date
}

struct RemoteHighlight: Codable {
    let id: UUID
    let publication_id: UUID
    let anchor: String
    let selected_text: String
    let context_before: String?
    let context_after: String?
    let category: String
    let color_token: String
    let created_at: Date
    let updated_at: Date
}

struct RemoteNote: Codable {
    let id: UUID
    let publication_id: UUID
    let highlight_id: UUID?
    let anchor: String?
    let body: String
    let tags: [String]
    let created_at: Date
    let updated_at: Date
}

struct RemoteReadingProgress: Codable {
    let id: UUID
    let publication_id: UUID
    let locator_json: String
    let percentage: Double
    let page_number: Int?
    let chapter_title: String?
    let device_id: String
    let version: Int
    let updated_at: Date
}
