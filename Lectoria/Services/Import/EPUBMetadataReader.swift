import UIKit
@preconcurrency import ReadiumShared
@preconcurrency import ReadiumStreamer

// MARK: - EPUBMetadataReader

/// Lee del propio EPUB (con Readium) el título, el autor y la portada al importarlo.
/// Antes se usaba solo el nombre del archivo y una portada de texto genérica
/// (Android tampoco lo hace todavía: usa el nombre del archivo). Si algo falla, quien llama usa el respaldo anterior.
enum EPUBMetadataReader {

    struct Info: Sendable {
        let title: String?
        let author: String?
    }

    /// Título y autores declarados en el paquete del EPUB.
    static func info(at url: URL) async -> Info? {
        guard let publication = await open(url) else { return nil }
        defer { publication.close() }
        let title = publication.metadata.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let author = publication.metadata.authors
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        return Info(
            title: title?.isEmpty == false ? title : nil,
            author: author.isEmpty ? nil : author
        )
    }

    /// Imagen de portada declarada en el EPUB, si tiene una.
    static func cover(at url: URL) async -> UIImage? {
        guard let publication = await open(url) else { return nil }
        defer { publication.close() }
        if case let .success(image?) = await publication.cover() {
            return image
        }
        return nil
    }

    private static func open(_ url: URL) async -> Publication? {
        guard let fileURL = FileURL(url: url) else { return nil }
        let retriever = AssetRetriever(httpClient: DefaultHTTPClient())
        guard case let .success(asset) = await retriever.retrieve(url: fileURL) else { return nil }
        let opener = PublicationOpener(parser: EPUBParser())
        guard case let .success(publication) = await opener.open(asset: asset, allowUserInteraction: false) else {
            return nil
        }
        return publication
    }
}
