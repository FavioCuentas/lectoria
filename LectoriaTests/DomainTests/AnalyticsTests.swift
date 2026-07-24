import Testing
import Foundation
@testable import Lectoria

struct AnalyticsTests {
    @Test
    func testPropertySanitization() async throws {
        let rawProps: [String: Any] = [
            "format": "epub",
            "title": "Un libro secreto de prueba", // Clave prohibida
            "author": "Autor Anónimo", // Clave prohibida
            "text": "Contenido confidencial", // Clave prohibida
            "duration_seconds": 180,
            "has_cover": true
        ]

        let sanitized = PropertySanitizer.sanitize(rawProps)

        #expect(sanitized["format"] == "epub")
        #expect(sanitized["duration_seconds"] == "180")
        #expect(sanitized["has_cover"] == "true")

        // Verificar que las claves prohibidas se eliminaron por completo
        #expect(sanitized["title"] == nil)
        #expect(sanitized["author"] == nil)
        #expect(sanitized["text"] == nil)
    }

    @Test
    func testPropertyBucketing() async throws {
        #expect(PropertySanitizer.bucketFileSize(500_000) == "<1MB")
        #expect(PropertySanitizer.bucketFileSize(3_000_000) == "1-5MB")
        #expect(PropertySanitizer.bucketFileSize(20_000_000) == ">15MB")

        #expect(PropertySanitizer.bucketDuration(30) == "<1min")
        #expect(PropertySanitizer.bucketDuration(120) == "1-5min")
        #expect(PropertySanitizer.bucketDuration(2000) == ">30min")

        #expect(PropertySanitizer.bucketTextLength(10) == "<50_chars")
        #expect(PropertySanitizer.bucketTextLength(150) == "50-200_chars")
        #expect(PropertySanitizer.bucketTextLength(500) == "200-1000_chars")
        #expect(PropertySanitizer.bucketTextLength(2000) == ">1000_chars")
    }

    @Test
    func testAnonymousInstallationIDPersistence() async throws {
        let id1 = AnonymousIdentityManager.shared.installationID
        let id2 = AnonymousIdentityManager.shared.installationID

        // Debe ser consistente y persistir en Keychain
        #expect(id1 == id2)
    }

    @Test
    func testMockAnalyticsTracking() async throws {
        let mockService = MockAnalyticsService()

        mockService.track(.documentImported, properties: ["format": "pdf"])
        mockService.track(.paywallViewed, properties: ["trigger_source": "ai_limit"])

        #expect(mockService.trackedEvents.count == 2)
        #expect(mockService.trackedEvents[0].name == .documentImported)
        #expect(mockService.trackedEvents[0].properties["format"] as? String == "pdf")
        #expect(mockService.trackedEvents[1].name == .paywallViewed)
    }
}
