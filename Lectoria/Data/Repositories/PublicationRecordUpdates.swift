import Foundation

// MARK: - PublicationRecordUpdates

/// Cambios puntuales sobre una publicación guardada, sin pisar el resto de sus campos.
@MainActor
enum PublicationRecordUpdates {
    /// Aplica `change` sobre el registro guardado (no sobre una copia que la vista tenía
    /// en memoria), para no pisar campos que otro proceso cambió mientras tanto, como el
    /// estado de indexado de la búsqueda global.
    static func update(
        _ id: UUID,
        repository: any PublicationRepository,
        change: (inout PublicationRecord) -> Void
    ) async {
        guard var fresh = try? await repository.fetch(id: id) else { return }
        change(&fresh)
        try? await repository.save(fresh)
    }

    /// Registra la fecha de apertura sobre el registro guardado, no sobre la copia del lector:
    /// las presentaciones se leen con una copia que apunta al PDF convertido, y guardarla
    /// cambiaba para siempre el archivo de la publicación.
    static func markOpened(_ id: UUID, repository: any PublicationRepository) async {
        await update(id, repository: repository) { $0.lastOpenedAt = Date() }
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
