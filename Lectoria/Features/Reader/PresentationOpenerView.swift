import SwiftUI

// MARK: - PresentationOpenerView

/// Abre una presentación. Los `.pptx` se convierten a PDF (mismo aspecto, una página por
/// diapositiva) y se leen con el lector de PDF de la app: búsqueda, resaltados, notas y progreso.
/// Si la conversión falla, o el formato no se puede convertir (`.ppt`, `.key`, `.odp`), se usa
/// la vista de presentación de siempre.
struct PresentationOpenerView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppDependencies.self) private var dependencies

    let record: PublicationRecord
    let initialPDFLocation: PDFLocation?
    let initialSearch: InitialSearch?
    @State private var route: PresentationOpenRoute

    init(record: PublicationRecord, initialPDFLocation: PDFLocation? = nil, initialSearch: InitialSearch? = nil) {
        self.record = record
        self.initialPDFLocation = initialPDFLocation
        self.initialSearch = initialSearch
        _route = State(initialValue: PresentationOpenRoute.decide(
            localFileName: record.localFileName,
            directory: RenderedPresentationStore.publicationsDirectory()
        ))
    }

    var body: some View {
        switch route {
        case .pdf(let pdfFileName):
            // Mismo registro (id, título, notas, progreso), apuntando al PDF convertido.
            PDFReaderView(record: pdfRecord(pdfFileName), initialLocation: initialPDFLocation, initialSearch: initialSearch)
        case .presentation:
            PresentationReaderView(record: record)
        case .convert:
            convertingView
                .task { await convert() }
        }
    }

    private func pdfRecord(_ pdfFileName: String) -> PublicationRecord {
        var copy = record
        copy.localFileName = pdfFileName
        return copy
    }

    private var convertingView: some View {
        let theme = themeManager.currentTheme
        return VStack(spacing: AppSpacing.md) {
            ProgressView()
                .tint(AppColor.accent(for: theme))
            Text(String(localized: "Convirtiendo la presentación a PDF…", comment: "Presentation: converting to PDF"))
                .font(AppTypography.body)
                .foregroundStyle(AppColor.textPrimary(for: theme))
            Text(String(localized: "Solo la primera vez", comment: "Presentation: conversion happens once"))
                .font(AppTypography.footnote)
                .foregroundStyle(AppColor.textSecondary(for: theme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.background(for: theme))
        .navigationTitle(record.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func convert() async {
        await dependencies.presentationRenderingService.ensureRendered(
            localFileName: record.localFileName,
            publicationID: record.id
        )
        let next = PresentationOpenRoute.decide(
            localFileName: record.localFileName,
            directory: RenderedPresentationStore.publicationsDirectory()
        )
        // Si no se pudo convertir, se abre como hasta ahora.
        route = next == .convert ? .presentation : next
    }
}
