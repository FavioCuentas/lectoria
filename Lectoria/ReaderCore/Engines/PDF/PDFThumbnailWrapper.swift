import SwiftUI
import PDFKit

// MARK: - PDFThumbnailWrapper

/// Wrapper de SwiftUI para el `PDFThumbnailView` nativo de PDFKit.
///
/// Permite renderizar una barra deslizante de miniaturas vinculada de forma reactiva
/// a un `PDFView` principal para navegar de forma visual por el documento.
struct PDFThumbnailWrapper: UIViewRepresentable {
    weak var pdfView: PDFView?

    func makeUIView(context: Context) -> PDFThumbnailView {
        let thumbnailView = PDFThumbnailView()
        thumbnailView.thumbnailSize = CGSize(width: 36, height: 54)
        thumbnailView.layoutMode = .horizontal
        thumbnailView.backgroundColor = .clear
        
        // Asociar el PDFView principal
        thumbnailView.pdfView = pdfView
        
        return thumbnailView
    }

    func updateUIView(_ uiView: PDFThumbnailView, context: Context) {
        if uiView.pdfView != pdfView {
            uiView.pdfView = pdfView
        }
    }
}
