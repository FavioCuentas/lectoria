import Foundation
import PDFKit
import UIKit
import WebKit
import os

private let logger = Logger(subsystem: "com.orvexa.Lectoria", category: "PresentationPDFConverter")

// MARK: - PresentationConversionError

enum PresentationConversionError: Error, Equatable {
    case loadFailed
    case timedOut
    case slideCountMismatch(found: Int, expected: Int)
    case emptyOutput
    case noWindowScene
}

// MARK: - PresentationPDFConverter

/// Convierte un `.pptx` a PDF (una página por diapositiva, con texto buscable) usando el
/// motor de QuickLook de WebKit, que es el mismo que usa la vista actual: la fidelidad es igual.
///
/// Lo aprendido en la prueba previa:
/// - WebKit genera un `div.slide` de 960×540 por diapositiva, pero las carga de forma perezosa.
/// - Siempre queda un `div.loading-slide` sobrante: no sirve como señal de fin. La señal es que
///   haya tantos `div.slide` como diapositivas reporta `PPTXParser`.
/// - La vista web debe estar en una `UIWindow` de la escena activa para pintar.
@MainActor
final class PresentationPDFConverter {
    private let timeout: Duration
    private let pollInterval: Duration = .milliseconds(500)
    private let settleDelay: Duration = .seconds(1)

    init(timeout: Duration = .seconds(30)) {
        self.timeout = timeout
    }

    /// Escribe el PDF en `destination` de forma atómica; si algo falla, no deja ningún archivo.
    func convert(pptxURL: URL, expectedSlideCount: Int, destination: URL) async throws {
        guard expectedSlideCount > 0 else { throw PresentationConversionError.emptyOutput }
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
            throw PresentationConversionError.noWindowScene
        }

        let frame = CGRect(x: 0, y: 0, width: 1280, height: 720)
        let window = UIWindow(windowScene: scene)
        window.frame = frame
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue - 1)
        window.alpha = 0.01
        window.isUserInteractionEnabled = false
        let webView = WKWebView(frame: frame)
        window.addSubview(webView)
        window.isHidden = false
        defer {
            webView.stopLoading()
            webView.removeFromSuperview()
            window.isHidden = true
        }

        try await load(pptxURL, in: webView)
        try await waitForSlides(expectedSlideCount, in: webView)
        let document = try await renderSlides(of: webView)

        guard document.pageCount > 0 else { throw PresentationConversionError.emptyOutput }
        guard document.pageCount == expectedSlideCount else {
            throw PresentationConversionError.slideCountMismatch(found: document.pageCount, expected: expectedSlideCount)
        }
        try writeAtomically(document, to: destination)
    }

    // MARK: - Pasos

    private func load(_ url: URL, in webView: WKWebView) async throws {
        let delegate = NavigationWaiter()
        webView.navigationDelegate = delegate
        await withCheckedContinuation { continuation in
            delegate.continuation = continuation
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        webView.navigationDelegate = nil
        // WebKit entrega el .pptx a su complemento de QuickLook y suele reportar
        // "Frame load interrupted" aunque la presentación se pinte bien. No es fatal:
        // el conteo de diapositivas (con tiempo máximo) decide si la carga funcionó.
        if let error = delegate.error {
            logger.debug("Carga con aviso de WebKit: \(error.localizedDescription)")
        }
    }

    private func waitForSlides(_ expected: Int, in webView: WKWebView) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        var found = 0
        while clock.now < deadline {
            found = await slideCount(in: webView)
            if found == expected {
                try await Task.sleep(for: settleDelay)
                found = await slideCount(in: webView)
                if found == expected { return }
            }
            // Forzar la carga perezosa de las diapositivas pendientes.
            _ = try? await webView.evaluateJavaScript(
                "var l=document.querySelector('.loading-slide')||Array.from(document.querySelectorAll('div.slide')).pop(); if(l){l.scrollIntoView();}"
            )
            try await Task.sleep(for: pollInterval)
        }
        if found > expected {
            throw PresentationConversionError.slideCountMismatch(found: found, expected: expected)
        }
        throw PresentationConversionError.timedOut
    }

    private func slideCount(in webView: WKWebView) async -> Int {
        (try? await webView.evaluateJavaScript("document.querySelectorAll('div.slide').length")) as? Int ?? 0
    }

    private func renderSlides(of webView: WKWebView) async throws -> PDFDocument {
        _ = try? await webView.evaluateJavaScript("window.scrollTo(0,0)")
        let json = (try? await webView.evaluateJavaScript(
            "JSON.stringify(Array.from(document.querySelectorAll('div.slide')).map(function(e){var r=e.getBoundingClientRect();return [r.x+window.scrollX,r.y+window.scrollY,r.width,r.height];}))"
        )) as? String ?? "[]"
        let rects = (try? JSONDecoder().decode([[Double]].self, from: Data(json.utf8))) ?? []

        let merged = PDFDocument()
        for r in rects where r.count == 4 && r[2] > 0 && r[3] > 0 {
            let configuration = WKPDFConfiguration()
            configuration.rect = CGRect(x: r[0], y: r[1], width: r[2], height: r[3])
            let data = try await webView.pdf(configuration: configuration)
            if let page = PDFDocument(data: data)?.page(at: 0) {
                merged.insert(page, at: merged.pageCount)
            }
        }
        return merged
    }

    private func writeAtomically(_ document: PDFDocument, to destination: URL) throws {
        let partial = destination.appendingPathExtension("partial")
        try? FileManager.default.removeItem(at: partial)
        guard document.write(to: partial) else { throw PresentationConversionError.emptyOutput }
        if FileManager.default.fileExists(atPath: destination.path) {
            _ = try FileManager.default.replaceItemAt(destination, withItemAt: partial)
        } else {
            try FileManager.default.moveItem(at: partial, to: destination)
        }
    }
}

// MARK: - NavigationWaiter

@MainActor
private final class NavigationWaiter: NSObject, WKNavigationDelegate {
    var continuation: CheckedContinuation<Void, Never>?
    private(set) var error: Error?

    private func finish(_ error: Error? = nil) {
        self.error = error
        continuation?.resume()
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { finish() }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish(error) }
}
