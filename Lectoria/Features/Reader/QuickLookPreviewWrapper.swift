import SwiftUI
import QuickLook

// MARK: - QuickLookPreviewWrapper

/// Wrapper de SwiftUI (`UIViewControllerRepresentable`) para el `QLPreviewController` nativo de Apple.
///
/// Permite renderizar presentaciones Microsoft PowerPoint (`.ppt` y `.pptx`) localmente
/// con la fidelidad vectorial completa del sistema operativo iOS.
struct QuickLookPreviewWrapper: UIViewControllerRepresentable {
    let fileURL: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        if context.coordinator.fileURL != fileURL {
            context.coordinator.fileURL = fileURL
            uiViewController.reloadData()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(fileURL: fileURL)
    }

    // MARK: - Coordinator (QLPreviewControllerDataSource)

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        var fileURL: URL

        init(fileURL: URL) {
            self.fileURL = fileURL
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return fileURL as QLPreviewItem
        }
    }
}
