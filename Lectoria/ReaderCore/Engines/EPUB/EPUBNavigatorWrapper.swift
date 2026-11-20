import SwiftUI
import WebKit
@preconcurrency import ReadiumShared
@preconcurrency import ReadiumNavigator
import os

private let logger = Logger(subsystem: "com.orvexa.Lectoria", category: "Reader")

// MARK: - EPUBNavigatorWrapper

/// Wrapper de SwiftUI para el `EPUBNavigatorViewController` de Readium.
///
/// Permite renderizar y controlar la paginación y formato de libros EPUB nativos
/// dentro de vistas SwiftUI, manteniendo sincronizado el progreso y las preferencias.
struct EPUBNavigatorWrapper: UIViewControllerRepresentable {
    let publication: Publication
    let initialLocation: EPUBLocation?
    
    @Binding var currentLocation: EPUBLocation?
    let preferences: EPUBPreferences
    
    @Binding var selectedText: String
    @Binding var hasSelection: Bool
    @Binding var selectedLocator: Locator?
    let highlights: [Highlight]
    
    /// Callback disparado al hacer tap en la pantalla (usado para alternar barras de herramientas).
    var onTap: ((CGPoint) -> Void)? = nil
    
    /// Ubicación externa forzada (para navegar desde el índice/TOC).
    var targetLocation: EPUBLocation? = nil

    /// Expone el navegador de Readium a SwiftUI (búsqueda: decoraciones y saltos directos).
    var navigatorBinding: Binding<EPUBNavigatorViewController?>? = nil

    /// Herramienta del lápiz (solo iPad): marcador o borrador; `nil` con la paleta oculta.
    var pencilTool: PencilTool? = nil
    /// Trazo del marcador terminado sobre texto: selección de Readium lista para guardar como destacado.
    var onPencilMark: ((Selection) -> Void)? = nil
    /// Trazo del borrador terminado: ids de los subrayados cuyo rango tocó el trazo.
    var onPencilErase: (([String]) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> EPUBNavigatorViewController {
        let config = EPUBNavigatorViewController.Configuration(
            preferences: preferences
        )
        
        do {
            let navigator = try EPUBNavigatorViewController(
                publication: publication,
                initialLocation: initialLocation?.locator,
                config: config
            )
            navigator.delegate = context.coordinator
            context.coordinator.navigator = navigator
            installPencil(on: navigator, coordinator: context.coordinator)
            exposeNavigator(navigator)
            return navigator
        } catch {
            logger.error("[EPUBNavigatorWrapper] Error al instanciar Navigator con posición inicial: \(error). Reintentando sin posición.")
            if let navigator = try? EPUBNavigatorViewController(
                publication: publication,
                initialLocation: nil,
                config: config
            ) {
                navigator.delegate = context.coordinator
                context.coordinator.navigator = navigator
                installPencil(on: navigator, coordinator: context.coordinator)
                exposeNavigator(navigator)
                return navigator
            }
            fatalError("No se pudo instanciar el EPUBNavigatorViewController de Readium: \(error.localizedDescription)")
        }
    }

    /// Trazo del lápiz sobre el libro (solo iPad; activo con el marcador o el borrador).
    private func installPencil(on navigator: EPUBNavigatorViewController, coordinator: Coordinator) {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }
        let recognizer = PencilStrokeRecognizer(target: coordinator, action: #selector(Coordinator.handlePencilStroke(_:)))
        navigator.view?.addGestureRecognizer(recognizer)
        coordinator.pencilRecognizer = recognizer
    }

    private func exposeNavigator(_ navigator: EPUBNavigatorViewController) {
        guard let navigatorBinding else { return }
        DispatchQueue.main.async {
            navigatorBinding.wrappedValue = navigator
        }
    }

    func updateUIViewController(_ uiViewController: EPUBNavigatorViewController, context: Context) {
        context.coordinator.parent = self
        context.coordinator.pencilRecognizer?.isEnabled = pencilTool != nil

        // Enviar las preferencias actualizadas al renderizador de Readium
        uiViewController.submitPreferences(preferences)
        
        // Manejar navegación externa solicitada (ej. saltos del TOC)
        if let target = targetLocation, target != context.coordinator.lastTarget {
            context.coordinator.lastTarget = target
            Task { @MainActor in
                _ = await uiViewController.go(to: target.locator, options: .animated)
            }
        }
        
        // Despejar selección reactivamente si hasSelection se pone en false externamente
        // (No durante un trazo del lápiz: la selección provisional es la sombra del trazo.)
        if !hasSelection && !context.coordinator.isPencilStroking {
            uiViewController.clearSelection()
        }
        
        // Renderizar los destacados usando la API de Decoraciones de Readium
        if let decorable = uiViewController as? DecorableNavigator {
            let decorations = highlights.compactMap { hl -> Decoration? in
                guard let locator = try? Locator(jsonString: hl.anchor) else {
                    return nil
                }
                
                let color = highlightColor(for: hl.colorToken)
                
                return Decoration(
                    id: hl.id.uuidString,
                    locator: locator,
                    style: .highlight(tint: color)
                )
            }
            decorable.apply(decorations: decorations, in: "highlights")
        }
    }
    
    private func highlightColor(for token: String) -> UIColor {
        switch token.lowercased() {
        case "idea principal", "blue", "mainidea":
            return UIColor(red: 0.30, green: 0.55, blue: 0.80, alpha: 0.35)
        case "duda", "purple", "question":
            return UIColor(red: 0.55, green: 0.38, blue: 0.75, alpha: 0.35)
        case "evidencia", "green", "evidence":
            return UIColor(red: 0.25, green: 0.65, blue: 0.45, alpha: 0.35)
        case "acción", "accion", "orange", "coral", "action":
            return UIColor(red: 0.85, green: 0.47, blue: 0.34, alpha: 0.35)
        case "cita", "pink", "quote":
            return UIColor(red: 0.80, green: 0.42, blue: 0.55, alpha: 0.35)
        default:
            return UIColor(red: 0.95, green: 0.80, blue: 0.30, alpha: 0.35)
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, EPUBNavigatorDelegate {
        var parent: EPUBNavigatorWrapper
        weak var navigator: EPUBNavigatorViewController?
        var lastTarget: EPUBLocation?

        // Lápiz
        weak var pencilRecognizer: PencilStrokeRecognizer?
        private(set) var isPencilStroking = false
        private weak var strokeWebView: WKWebView?
        private var strokeStart: CGPoint = .zero

        init(_ parent: EPUBNavigatorWrapper) {
            self.parent = parent
        }

        // MARK: - Lápiz

        @objc func handlePencilStroke(_ recognizer: PencilStrokeRecognizer) {
            guard let navigator, let host = navigator.view else { return }
            switch recognizer.state {
            case .began:
                let start = recognizer.startLocation(in: host)
                guard let webView = Self.webView(at: start, in: host) else { return }
                isPencilStroking = true
                strokeWebView = webView
                strokeStart = Self.clientPoint(start, from: host, in: webView)
                runStroke(to: recognizer.location(in: host), host: host, wantIDs: false, completion: nil)
            case .changed:
                runStroke(to: recognizer.location(in: host), host: host, wantIDs: false, completion: nil)
            case .ended:
                let tool = parent.pencilTool
                runStroke(to: recognizer.location(in: host), host: host, wantIDs: tool == .eraser) { [weak self] text, ids in
                    self?.finishStroke(text: text, ids: ids, tool: tool)
                }
            default:
                endStroke()
            }
        }

        /// Selecciona en la página web desde el inicio del trazo hasta `point` (palabras completas).
        /// Con `wantIDs`, devuelve además los subrayados de Readium cuyo rango se solapa con el trazo.
        private func runStroke(to point: CGPoint, host: UIView, wantIDs: Bool,
                               completion: ((String, [String]) -> Void)?) {
            guard isPencilStroking, let webView = strokeWebView else { completion?("", []); return }
            let end = Self.clientPoint(point, from: host, in: webView)
            let script = String(format: Self.strokeScript, strokeStart.x, strokeStart.y, end.x, end.y, wantIDs ? 1 : 0)
            webView.evaluateJavaScript(script) { result, _ in
                guard let json = (result as? String)?.data(using: .utf8),
                      let object = try? JSONSerialization.jsonObject(with: json) as? [String: Any] else {
                    completion?("", [])
                    return
                }
                completion?(object["text"] as? String ?? "", object["ids"] as? [String] ?? [])
            }
        }

        private func finishStroke(text: String, ids: [String], tool: PencilTool?) {
            let expected = Self.normalize(text)
            switch tool {
            case .eraser:
                endStroke()
                if !ids.isEmpty { parent.onPencilErase?(ids) }
            case .marker:
                guard !expected.isEmpty, let navigator else { endStroke(); return }
                // Readium recibe la selección por un mensaje de JavaScript (con 50 ms de espera):
                // se espera a que llegue la del final del trazo, no una intermedia.
                Task { @MainActor [weak self] in
                    var latest: Selection?
                    for _ in 0..<12 {
                        if let selection = navigator.currentSelection,
                           !(selection.locator.text.highlight ?? "").isEmpty {
                            latest = selection
                            if Self.normalize(selection.locator.text.highlight ?? "") == expected { break }
                        }
                        try? await Task.sleep(for: .milliseconds(50))
                    }
                    self?.endStroke()
                    if let latest { self?.parent.onPencilMark?(latest) }
                }
            default:
                endStroke()
            }
        }

        private func endStroke() {
            isPencilStroking = false
            strokeWebView = nil
            navigator?.clearSelection()
        }

        private static func normalize(_ text: String) -> String {
            text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        }

        /// Página web bajo el punto; si el trazo empieza en un margen, la que ocupa esa columna.
        private static func webView(at point: CGPoint, in host: UIView) -> WKWebView? {
            var view = host.hitTest(point, with: nil)
            while let current = view {
                if let webView = current as? WKWebView { return webView }
                view = current.superview
            }
            return allWebViews(in: host).first { webView in
                let frame = webView.convert(webView.bounds, to: host)
                return frame.minX <= point.x && point.x <= frame.maxX && webView.window != nil && !webView.isHidden
            }
        }

        private static func allWebViews(in view: UIView) -> [WKWebView] {
            if let webView = view as? WKWebView { return [webView] }
            return view.subviews.flatMap { allWebViews(in: $0) }
        }

        /// Punto en coordenadas de la ventana visible de la página web (las de `caretRangeFromPoint`).
        /// Igual que Readium: el margen del contenido solo desplaza mientras `contentOffset` es negativo.
        private static func clientPoint(_ point: CGPoint, from host: UIView, in webView: WKWebView) -> CGPoint {
            let local = webView.convert(point, from: host)
            let offset = webView.scrollView.contentOffset
            let zoom = max(webView.scrollView.zoomScale, 0.01)
            return CGPoint(x: (local.x + min(0, offset.x)) / zoom, y: (local.y + min(0, offset.y)) / zoom)
        }

        /// Selección entre dos puntos (ajustados a la ventana), ampliada a palabras completas.
        /// Devuelve JSON con el texto y, si se pide, los ids de los subrayados que se solapan.
        private static let strokeScript = """
        (function(x1, y1, x2, y2, wantIDs) {
          function clampX(x) { return Math.min(Math.max(x, 0), window.innerWidth - 1); }
          function clampY(y) { return Math.min(Math.max(y, 0), window.innerHeight - 1); }
          var a = document.caretRangeFromPoint(clampX(x1), clampY(y1));
          var b = document.caretRangeFromPoint(clampX(x2), clampY(y2));
          if (!a || !b) { return JSON.stringify({ text: "", ids: [] }); }
          var first = a, last = b;
          if (a.compareBoundaryPoints(Range.START_TO_START, b) > 0) { first = b; last = a; }
          var range = document.createRange();
          range.setStart(first.startContainer, first.startOffset);
          range.setEnd(last.startContainer, last.startOffset);
          var word = /[\\p{L}\\p{N}'’-]/u;
          if (range.startContainer.nodeType === 3) {
            var t = range.startContainer.data, o = range.startOffset;
            while (o > 0 && word.test(t[o - 1])) { o--; }
            range.setStart(range.startContainer, o);
          }
          if (range.endContainer.nodeType === 3) {
            var t2 = range.endContainer.data, o2 = range.endOffset;
            while (o2 < t2.length && word.test(t2[o2])) { o2++; }
            range.setEnd(range.endContainer, o2);
          }
          var selection = window.getSelection();
          selection.removeAllRanges();
          selection.addRange(range);
          var ids = [];
          if (wantIDs && window.readium && window.readium.getDecorations) {
            var items = window.readium.getDecorations("highlights").items || [];
            for (var i = 0; i < items.length; i++) {
              var r = items[i].range;
              if (!r) { continue; }
              var overlaps = r.compareBoundaryPoints(Range.START_TO_END, range) < 0
                          && r.compareBoundaryPoints(Range.END_TO_START, range) > 0;
              if (overlaps) { ids.push(items[i].decoration.id); }
            }
          }
          return JSON.stringify({ text: selection.toString(), ids: ids });
        })(%f, %f, %f, %f, %d)
        """

        // MARK: - EPUBNavigatorDelegate

        func navigator(_ navigator: Navigator, locationDidChange locator: Locator) {
            // Sincronizar el progreso actual de lectura con SwiftUI
            parent.currentLocation = EPUBLocation(locator: locator)
        }

        func navigator(_ navigator: VisualNavigator, didTapAt point: CGPoint) {
            let width = navigator.view.bounds.width
            let leftZone = width * 0.25
            let rightZone = width * 0.75
            
            if point.x < leftZone {
                Task { @MainActor in
                    _ = await navigator.goBackward()
                }
            } else if point.x > rightZone {
                Task { @MainActor in
                    _ = await navigator.goForward()
                }
            } else {
                // Propagar gestos de toque
                parent.onTap?(point)
            }
            
            // Si el usuario toca la pantalla, despejar la selección activa
            parent.selectedText = ""
            parent.hasSelection = false
            parent.selectedLocator = nil
        }

        func navigator(_ navigator: Navigator, presentError error: NavigatorError) {
            // Manejo de errores de navegación
            logger.error("[EPUBNavigatorWrapper] Error del navegador: \(error)")
        }
        
        func navigator(_ navigator: SelectableNavigator, shouldShowMenuForSelection selection: Selection) -> Bool {
            // La selección de un trazo del lápiz no abre el menú de Lectoria.
            guard !isPencilStroking else { return false }
            parent.selectedText = selection.locator.text.highlight ?? ""
            parent.hasSelection = true
            parent.selectedLocator = selection.locator
            
            // Retornamos false para ocultar el menú del sistema y mostrar el menú flotante propio de Lectoria
            return false
        }
    }
}
