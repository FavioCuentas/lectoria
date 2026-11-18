import Foundation

// MARK: - PublicationRecordUpdates

/// Cambios puntuales sobre una publicación guardada, sin pisar el resto de sus campos.
@MainActor
enum PublicationRecordUpdates {
    /// Registra la fecha de apertura sobre el registro guardado, no sobre la copia del lector:
    /// las presentaciones se leen con una copia que apunta al PDF convertido, y guardarla
    /// cambiaba para siempre el archivo de la publicación.
    static func markOpened(_ id: UUID, repository: any PublicationRepository) async {
        guard var fresh = try? await repository.fetch(id: id) else { return }
        fresh.lastOpenedAt = Date()
        try? await repository.save(fresh)
    }

    /// Repara presentaciones cuyo archivo quedó apuntando al PDF convertido
    /// (`x.pptx.rendered.pdf` → `x.pptx`) y las vuelve a indexar.
    static func repairPresentationFileNames(repository: any PublicationRepository) async {
        let all = (try? await repository.fetchAll()) ?? []
        for var record in all where record.publicationType == .pptx
            && record.localFileName.hasSuffix(RenderedPresentationStore.suffix) {
            record.localFileName = String(record.localFileName.dropLast(RenderedPresentationStore.suffix.count))
            record.indexingStatus = .pending
            try? await repository.save(record)
        }
    }
}
