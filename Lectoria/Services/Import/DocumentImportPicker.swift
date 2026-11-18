import UIKit
import UniformTypeIdentifiers

// MARK: - DocumentImportPicker

/// Presenta el selector de archivos del sistema desde UIKit, sobre el controlador
/// visible más alto de la ventana activa.
///
/// Sustituye a `.fileImporter` de SwiftUI: atado a una vista dentro de un `TabView`/
/// `NavigationStack`, el selector se reiniciaba cada vez que esa vista se volvía a
/// renderizar (p. ej. al escribir en el buscador del selector). Presentado desde UIKit,
/// su ciclo de vida ya no depende de las actualizaciones de SwiftUI.
@MainActor
final class DocumentImportPicker: NSObject, UIDocumentPickerDelegate {
    private var completion: ((URL?) -> Void)?

    /// Muestra el selector. Devuelve `false` si no hay un controlador desde el que presentarlo.
    @discardableResult
    func present(contentTypes: [UTType], completion: @escaping (URL?) -> Void) -> Bool {
        guard let presenter = Self.topViewController() else { return false }

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: false)
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        picker.delegate = self
        self.completion = completion
        presenter.present(picker, animated: true)
        return true
    }

    // MARK: UIDocumentPickerDelegate

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        finish(with: urls.first)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        finish(with: nil)
    }

    // MARK: Private

    private func finish(with url: URL?) {
        let completion = self.completion
        self.completion = nil
        completion?(url)
    }

    /// Controlador visible más alto de la escena activa (para presentar encima de sheets).
    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        let window = scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}
