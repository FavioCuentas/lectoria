import Testing
import Foundation
@testable import Lectoria

// MARK: - PublicationTypeTests

/// Pruebas unitarias para PublicationType y PublicationRecord.
struct PublicationTypeTests {

    // MARK: - PublicationType

    @Test("All publication types have non-empty display names")
    func displayNames() {
        for type in PublicationType.allCases {
            #expect(!type.displayName.isEmpty, "\(type) should have a display name")
        }
    }

    @Test("All publication types have system images")
    func systemImages() {
        for type in PublicationType.allCases {
            #expect(!type.systemImage.isEmpty, "\(type) should have a system image")
        }
    }

    @Test("All publication types have MIME types")
    func mimeTypes() {
        for type in PublicationType.allCases {
            #expect(!type.mimeType.isEmpty, "\(type) should have a MIME type")
        }
    }

    @Test("File-based types have file extensions")
    func fileExtensions() {
        for type in PublicationType.allCases where type.isFileBased {
            #expect(!type.fileExtensions.isEmpty,
                    "\(type) is file-based but has no file extensions")
        }
    }

    @Test("Pasted text is not file-based")
    func pastedTextNotFileBased() {
        #expect(!PublicationType.pastedText.isFileBased)
        #expect(PublicationType.pastedText.fileExtensions.isEmpty)
    }

    // MARK: - Format detection

    @Test("Detects epub format from extension")
    func detectEpub() {
        #expect(PublicationType.from(fileExtension: "epub") == .epub)
        #expect(PublicationType.from(fileExtension: "EPUB") == .epub)
    }

    @Test("Detects pdf format from extension")
    func detectPdf() {
        #expect(PublicationType.from(fileExtension: "pdf") == .pdf)
        #expect(PublicationType.from(fileExtension: "PDF") == .pdf)
    }

    @Test("Detects txt format from extension")
    func detectTxt() {
        #expect(PublicationType.from(fileExtension: "txt") == .txt)
        #expect(PublicationType.from(fileExtension: "text") == .txt)
    }

    @Test("Detects markdown format from extension")
    func detectMarkdown() {
        #expect(PublicationType.from(fileExtension: "md") == .markdown)
        #expect(PublicationType.from(fileExtension: "markdown") == .markdown)
    }

    @Test("Returns nil for unknown extension")
    func unknownExtension() {
        #expect(PublicationType.from(fileExtension: "docx") == nil)
        #expect(PublicationType.from(fileExtension: "mobi") == nil)
        #expect(PublicationType.from(fileExtension: "") == nil)
    }

    // MARK: - PublicationRecord

    @Test("New import creates valid record")
    func newImport() {
        let record = PublicationRecord.newImport(
            title: "Test Book",
            author: "Author",
            publicationType: .epub,
            localFileName: "test.epub",
            mimeType: "application/epub+zip",
            fileSize: 1000,
            sha256: "abc123"
        )

        #expect(!record.id.uuidString.isEmpty)
        #expect(record.title == "Test Book")
        #expect(record.author == "Author")
        #expect(record.publicationType == .epub)
        #expect(record.fileSize == 1000)
        #expect(record.sha256 == "abc123")
        #expect(!record.isFavorite)
        #expect(!record.isArchived)
        #expect(!record.isCloudBackedUp)
        #expect(record.indexingStatus == .pending)
        #expect(record.syncStatus == .local)
        #expect(!record.hasBeenOpened)
        #expect(!record.isFinished)
    }

    @Test("Publication record is Codable")
    func codable() throws {
        let original = PublicationRecord.newImport(
            title: "Codable Test",
            publicationType: .pdf,
            localFileName: "test.pdf",
            mimeType: "application/pdf",
            fileSize: 500,
            sha256: "def456"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PublicationRecord.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.title == original.title)
        #expect(decoded.publicationType == original.publicationType)
        #expect(decoded.sha256 == original.sha256)
    }

    @Test("Publication record conforms to Sendable")
    func sendable() async {
        let record = PublicationRecord.newImport(
            title: "Sendable Test",
            publicationType: .txt,
            localFileName: "test.txt",
            mimeType: "text/plain",
            fileSize: 100,
            sha256: "ghi789"
        )

        // Verify can be passed across concurrency boundaries
        let title = await Task.detached {
            record.title
        }.value

        #expect(title == "Sendable Test")
    }

    // MARK: - AppError

    @Test("All import errors have descriptions")
    func importErrorDescriptions() {
        let errors: [AppError] = [
            .unsupportedFormat(fileExtension: "docx"),
            .corruptedFile(fileName: "test.epub"),
            .duplicatePublication(existingID: UUID()),
            .insufficientStorage,
            .accessDenied(fileName: "test.pdf"),
            .fileTooLarge(sizeMB: 100),
        ]

        for error in errors {
            #expect(error.errorDescription != nil, "\(error) should have a description")
            #expect(!error.alertTitle.isEmpty, "\(error) should have an alert title")
        }
    }

    @Test("Duplicate error should not be logged")
    func duplicateNotLogged() {
        let error = AppError.duplicatePublication(existingID: UUID())
        #expect(!error.shouldLog)
    }

    @Test("Corrupted file error should be logged")
    func corruptedFileLogged() {
        let error = AppError.corruptedFile(fileName: "test.epub")
        #expect(error.shouldLog)
    }
}
