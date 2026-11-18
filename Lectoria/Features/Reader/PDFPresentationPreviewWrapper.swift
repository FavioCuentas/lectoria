import SwiftUI
import PDFKit

// MARK: - PDFPresentationPreviewWrapper

/// Envoltorio `UIViewRepresentable` para visualizar un PDF derivado de presentación con alta fidelidad vectorial vía `PDFKit`.
///
/// Implementa un `Coordinator` aislado en `@MainActor` que sincroniza bidireccionalmente la página activa con `pageIndex`,
/// monitoriza la selección de texto en la diapositiva y proyecta resaltados guardados.
struct PDFPresentationPreviewWrapper: UIViewRepresentable {
    let pdfDocument: PDFDocument
    @Binding var pageIndex: Int
    let annotations: [PresentationAnnotation]
    let onTextSelected: ((String, CGRect, Int) -> Void)?
    let onSelectionCleared: (() -> Void)?
    let onAddNoteRequest: ((String, Int) -> Void)?
    let onTranslateRequest: ((String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = CustomPDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .horizontal
        pdfView.backgroundColor = .clear
        pdfView.document = pdfDocument

        let addNoteItem = UIMenuItem(title: NSLocalizedString("Añadir nota", comment: "Add note menu item"), action: #selector(CustomPDFView.addNoteAction(_:)))
        UIMenuController.shared.menuItems = [addNoteItem]

        pdfView.onAddNote = {
            if let selection = pdfView.currentSelection, let text = selection.string,
               let page = pdfView.currentPage {
                let slideIdx = pdfDocument.index(for: page)
                onAddNoteRequest?(text, slideIdx)
            }
        }

        context.coordinator.attach(to: pdfView)

        if let page = pdfDocument.page(at: pageIndex) {
            pdfView.go(to: page)
        }

        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document != pdfDocument {
            pdfView.document = pdfDocument
        }

        // Actualizar la página solo si varió externamente para evitar ciclos infinitos
        if !context.coordinator.isUpdatingFromPDFView,
           let page = pdfDocument.page(at: pageIndex),
           pdfView.currentPage != page {
            pdfView.go(to: page)
        }

        // Renderizar o actualizar resaltados de la página activa
        context.coordinator.renderAnnotations(on: pdfView)
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject {
        var parent: PDFPresentationPreviewWrapper
        var isUpdatingFromPDFView = false
        nonisolated(unsafe) private var notificationObservers: [any NSObjectProtocol] = []

        init(_ parent: PDFPresentationPreviewWrapper) {
            self.parent = parent
            super.init()
        }

        deinit {
            // Eliminar observadores en deinit
            let observers = notificationObservers
            notificationObservers.removeAll()
            observers.forEach { NotificationCenter.default.removeObserver($0) }
        }

        func attach(to pdfView: PDFView) {
            // Escuchar cambios de página del PDFView (desplazamiento manual o gesto)
            let pageObserver = NotificationCenter.default.addObserver(
                forName: .PDFViewPageChanged,
                object: pdfView,
                queue: .main
            ) { [weak self, weak pdfView] _ in
                Task { @MainActor [weak self, weak pdfView] in
                    guard let self = self, let pdfView = pdfView, let currentPage = pdfView.currentPage else { return }
                    let newIndex = pdfView.document?.index(for: currentPage) ?? 0
                    if self.parent.pageIndex != newIndex {
                        self.isUpdatingFromPDFView = true
                        self.parent.pageIndex = newIndex
                        Task { @MainActor in
                            self.isUpdatingFromPDFView = false
                        }
                    }
                }
            }

            // Escuchar cambios en la selección de texto
            let selectionObserver = NotificationCenter.default.addObserver(
                forName: .PDFViewSelectionChanged,
                object: pdfView,
                queue: .main
            ) { [weak self, weak pdfView] _ in
                Task { @MainActor [weak self, weak pdfView] in
                    guard let self = self, let pdfView = pdfView else { return }
                    if let selection = pdfView.currentSelection,
                       let text = selection.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       let page = pdfView.currentPage {
                        let bounds = selection.bounds(for: page)
                        let slideIdx = pdfView.document?.index(for: page) ?? 0
                        self.parent.onTextSelected?(text, bounds, slideIdx)
                    } else {
                        self.parent.onSelectionCleared?()
                    }
                }
            }

            notificationObservers.append(pageObserver)
            notificationObservers.append(selectionObserver)
        }

        func renderAnnotations(on pdfView: PDFView) {
            guard let page = pdfView.currentPage else { return }
            let slideIdx = pdfView.document?.index(for: page) ?? 0

            // Limpiar anotaciones previas creadas dinámicamente
            page.annotations.forEach { ann in
                if ann.userName == "LectoriaHighlight" {
                    page.removeAnnotation(ann)
                }
            }

            // Aplicar anotaciones correspondientes al slide activo
            let slideAnnotations = parent.annotations.filter { $0.slideIndex == slideIdx }
            for annData in slideAnnotations {
                if let geom = annData.selectionGeometry {
                    let highlight = PDFAnnotation(bounds: geom.cgRect, forType: .highlight, withProperties: nil)
                    highlight.userName = "LectoriaHighlight"
                    highlight.color = categoryColor(annData.categoryID ?? "Importante")
                    page.addAnnotation(highlight)
                }
            }
        }

        private func categoryColor(_ category: String) -> UIColor {
            switch category {
            case "Importante": UIColor(red: 0.95, green: 0.77, blue: 0.06, alpha: 0.4)
            case "Definición": UIColor(red: 0.20, green: 0.60, blue: 0.86, alpha: 0.4)
            case "Ejemplo": UIColor(red: 0.18, green: 0.80, blue: 0.44, alpha: 0.4)
            case "Duda": UIColor(red: 0.91, green: 0.30, blue: 0.24, alpha: 0.4)
            case "Estudio": UIColor(red: 0.90, green: 0.49, blue: 0.13, alpha: 0.4)
            default: UIColor.yellow.withAlphaComponent(0.4)
            }
        }
    }
}

// MARK: - CustomPDFView

private class CustomPDFView: PDFView {
    var onAddNote: (() -> Void)?

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(copy(_:)) || action == #selector(addNoteAction(_:)) {
            return true
        }
        return super.canPerformAction(action, withSender: sender)
    }

    @objc fileprivate func addNoteAction(_ sender: Any?) {
        onAddNote?()
    }
}
