import Foundation

// MARK: - AnalyticsEvent

/// Representa un evento de analítica de producto fuertemente tipado en Lectoria.
///
/// Garantiza que solo se envíen eventos definidos en el catálogo y que
/// las propiedades se mantengan anonimizadas y libres de contenido privado.
public enum AnalyticsEventName: String, Codable, Sendable {
    // Lifecycle
    case appLaunched = "app_launched"

    // Auth
    case userSignedIn = "user_signed_in"
    case guestModeEntered = "guest_mode_entered"

    // Import
    case documentImported = "document_imported"
    case documentImportFailed = "document_import_failed"

    // Library
    case libraryViewed = "library_viewed"

    // Reader & Sessions
    case documentOpened = "document_opened"
    case readingSessionEnded = "reading_session_ended"

    // Annotations
    case highlightCreated = "highlight_created"
    case noteCreated = "note_created"
    case bookmarkAdded = "bookmark_added"

    // Tools
    case dictionaryLookedUp = "dictionary_looked_up"
    case translationRequested = "translation_requested"
    case aiQueryExecuted = "ai_query_executed"
    case ttsSessionStarted = "tts_session_started"

    // Monetization
    case paywallViewed = "paywall_viewed"
    case purchaseCompleted = "purchase_completed"

    // Technical
    case errorOccurred = "error_occurred"
}

// MARK: - AnalyticsEventRecord

/// Representa una instancia concreta de un evento de analítica listo para ser procesado o guardado.
public struct AnalyticsEventRecord: Sendable, Codable, Identifiable {
    public let id: UUID
    public let sessionID: UUID
    public let installationID: UUID
    public let userID: String?
    public let eventName: AnalyticsEventName
    public let properties: [String: String]
    public let appVersion: String
    public let osVersion: String
    public let deviceFamily: String
    public let clientTimestamp: Date

    public init(
        id: UUID = UUID(),
        sessionID: UUID,
        installationID: UUID,
        userID: String? = nil,
        eventName: AnalyticsEventName,
        properties: [String: String] = [:],
        appVersion: String,
        osVersion: String,
        deviceFamily: String,
        clientTimestamp: Date = Date()
    ) {
        self.id = id
        self.sessionID = sessionID
        self.installationID = installationID
        self.userID = userID
        self.eventName = eventName
        self.properties = properties
        self.appVersion = appVersion
        self.osVersion = osVersion
        self.deviceFamily = deviceFamily
        self.clientTimestamp = clientTimestamp
    }
}
