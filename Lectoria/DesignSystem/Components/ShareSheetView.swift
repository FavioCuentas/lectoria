import SwiftUI
import UIKit

// MARK: - ShareSheetView

/// Wrapper de SwiftUI para UIActivityViewController que permite compartir archivos reales
/// (PDF, Word .docx, TXT, Markdown) con la hoja nativa de iOS.
struct ShareSheetView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
