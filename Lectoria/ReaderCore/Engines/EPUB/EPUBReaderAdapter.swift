import Foundation
@preconcurrency import ReadiumShared
@preconcurrency import ReadiumStreamer
@preconcurrency import ReadiumNavigator

// MARK: - EPUBReaderAdapter

/// Adaptador del motor de lectura EPUB usando Readium Swift Toolkit.
///
/// Implementa `PublicationEngine` usando `EPUBLocation` como posición.
@MainActor
final class EPUBReaderAdapter: PublicationEngine {
    typealias Location = EPUBLocation

    private let opener: PublicationOpener
    private let httpClient: HTTPClient
    private(set) var publication: Publication?
    private var fileURL: URL?

    init() {
        self.httpClient = DefaultHTTPClient()
        self.opener = PublicationOpener(parser: EPUBParser())
    }

    /// Abre una publicación EPUB de forma asíncrona.
    func open(publication record: PublicationRecord) async throws {
        // Resolver ruta física del documento en el contenedor privado
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw NSError(
                domain: "EPUBReaderAdapter",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "No se pudo resolver el directorio Application Support."]
            )
        }
        let fileURL = appSupport.appendingPathComponent("Publications/\(record.localFileName)")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw NSError(
                domain: "EPUBReaderAdapter",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "El archivo no existe en el almacenamiento local."]
            )
        }
        
        self.fileURL = fileURL
        
        // Convertir la URL local al tipo FileURL de Readium
        guard let absoluteURL = FileURL(url: fileURL) else {
            throw NSError(
                domain: "EPUBReaderAdapter",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "URL de archivo local no es válida para Readium."]
            )
        }
        
        // Cargar el asset y abrir la publicación con Readium PublicationOpener
        let retriever = AssetRetriever(httpClient: httpClient)
        
        switch await retriever.retrieve(url: absoluteURL) {
        case let .success(asset):
            let result = await opener.open(asset: asset, allowUserInteraction: false)
            switch result {
            case let .success(openedPub):
                self.publication = openedPub
            case let .failure(error):
                throw error
            }
        case let .failure(error):
            throw error
        }
    }

    /// Cierra el libro y libera memoria.
    func close() async {
        self.publication = nil
        self.fileURL = nil
    }

    /// La ubicación actual es provista por el controlador de navegación en tiempo real.
    func currentLocation() async -> EPUBLocation? {
        // Será sobreescrito o enlazado por el wrapper de UI en SwiftUI.
        return nil
    }

    /// Navegación dirigida por el controlador.
    func go(to location: EPUBLocation) async throws {
        // Se enlazará con la navegación del EPUBNavigatorViewController.
    }

    /// Realiza una búsqueda simple dentro del contenido.
    func search(_ query: String) async throws -> [SearchResult] {
        // En Fase 3 se integrará la búsqueda nativa de Readium.
        return []
    }

    /// Obtiene la Tabla de Contenidos estructurada para la interfaz.
    func tableOfContents() async throws -> [TOCItem] {
        guard let publication = publication else { return [] }
        let linksResult = await publication.tableOfContents()
        let links = (try? linksResult.get()) ?? []
        return mapLinkList(links)
    }

    // MARK: - Helpers

    /// Mapea recursivamente la lista de enlaces de Readium a TOCItem de Lectoria.
    private func mapLinkList(_ links: [Link]) -> [TOCItem] {
        links.map { link in
            let children = mapLinkList(link.children)
            
            // Crear un locator a partir del enlace para guardar la posición de destino
            let locator = Locator(
                href: link.url(),
                mediaType: link.mediaType ?? .html,
                title: link.title
            )
            
            let locationData = (try? JSONEncoder().encode(EPUBLocation(locator: locator))) ?? Data()
            
            return TOCItem(
                title: link.title ?? link.href,
                level: 0,
                locationData: locationData,
                children: children
            )
        }
    }
}
