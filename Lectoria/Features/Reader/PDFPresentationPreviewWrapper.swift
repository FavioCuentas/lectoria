import SwiftUI
import PDFKit

// MARK: - PDFPresentationPreviewWrapper

/// Envoltorio `UIViewRepresentable` para visualizar un PDF derivado de presentación con alta fidelidad vectorial vía `PDFKit`.
///
/// Configura `PDFView` en modo de diapositiva única (`singlePage`) con escalado automático (`autoScales = true`)
/// e inmutabilidad visual.
struct PDFPresentationPreviewWrapper: UIViewRepresentable {
    let pdfDocument: PDFDocument
    let pageIndex: Int

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .horizontal
        pdfView.backgroundColor = .clear
        pdfView.document = pdfDocument
        if let page = pdfDocument.page(at: pageIndex) {
            pdfView.go(to: page)
        }
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document != pdfDocument {
            pdfView.document = pdfDocument
        }

        if let page = pdfDocument.page(at: pageIndex), pdfView.currentPage != page {
            pdfView.go(to: page)
        }
    }
}
