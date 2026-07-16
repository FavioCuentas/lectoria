import SwiftUI
import PDFKit

// MARK: - PDFNavigatorWrapper

/// Wrapper de SwiftUI para el `PDFView` de PDFKit.
///
/// Permite renderizar y controlar la navegación, zoom y modo de lectura de documentos PDF,
/// manteniendo sincronizado el progreso con la base de datos de Lectoria.
struct PDFNavigatorWrapper: UIViewRepresentable {
    let document: PDFDocument
    let initialLocation: PDFLocation?
    
    @Binding var currentLocation: PDFLocation?
    let isScrollMode: Bool
    
    @Binding var selectedText: String
    @Binding var hasSelection: Bool
    let highlights: [Highlight]
    
    /// Binding para exponer el PDFView nativo hacia SwiftUI (útil para vincular el control de miniaturas)
    var pdfViewBinding: Binding<PDFView?>? = nil
    
    /// Callback disparado al hacer tap en la pantalla (para alternar barras de herramientas).
    var onTap: ((CGPoint) -> Void)? = nil
    
    /// Ubicación externa forzada (para navegar desde el índice o marcadores).
    var targetLocation: PDFLocation? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.minScaleFactor = pdfView.scaleFactorForSizeToFit
        pdfView.maxScaleFactor = 4.0
        
        // Configurar modo de visualización inicial
        updateDisplayMode(pdfView)
        
        // Agregar gesto de tap para alternar la UI chrome
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tapGesture.delegate = context.coordinator
        pdfView.addGestureRecognizer(tapGesture)
        
        // Registrar observación de cambio de página y selección
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.handlePageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.handleSelectionChanged(_:)),
            name: .PDFViewSelectionChanged,
            object: pdfView
        )
        
        // Ir a la página inicial si existe
        if let initial = initialLocation,
           let page = document.page(at: initial.pageIndex) {
            pdfView.go(to: page)
        }
        
        // Renderizar destacados iniciales
        renderHighlights(on: pdfView)
        
        // Exponer la referencia del PDFView al coordinador para otros usos (ej. miniaturas)
        context.coordinator.pdfView = pdfView
        
        if let pdfViewBinding {
            DispatchQueue.main.async {
                pdfViewBinding.wrappedValue = pdfView
            }
        }
        
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        // Actualizar modo de desplazamiento continuo vertical vs horizontal paginado
        let modeChanged = (isScrollMode && uiView.displayMode != .singlePageContinuous) ||
                          (!isScrollMode && uiView.displayMode != .singlePage)
        
        if modeChanged {
            updateDisplayMode(uiView)
        }
        
        // Navegación externa dirigida (ej. TOC o marcador)
        if let target = targetLocation, target != context.coordinator.lastTarget {
            context.coordinator.lastTarget = target
            if let page = document.page(at: target.pageIndex) {
                uiView.go(to: page)
            }
        }
        
        // Redibujar destacados solo cuando cambie su cantidad
        if highlights.count != context.coordinator.lastHighlightsCount {
            context.coordinator.lastHighlightsCount = highlights.count
            renderHighlights(on: uiView)
        }
    }
    
    private func renderHighlights(on uiView: PDFView) {
        guard let document = uiView.document else { return }
        
        // 1. Limpiar anotaciones previas creadas por Lectoria
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            let annotations = page.annotations
            for ann in annotations {
                if ann.userName == "Lectoria" {
                    page.removeAnnotation(ann)
                }
            }
        }
        
        // 2. Renderizar destacados actuales
        for highlight in highlights {
            guard let data = highlight.anchor.data(using: .utf8),
                  let location = try? JSONDecoder().decode(PDFLocation.self, from: data) else { continue }
            
            let selections = document.findString(highlight.selectedText, withOptions: [])
            for selection in selections {
                guard let firstPage = selection.pages.first else { continue }
                let pageIndex = document.index(for: firstPage)
                
                if pageIndex == location.pageIndex {
                    let bounds = selection.bounds(for: firstPage)
                    let annotation = PDFAnnotation(
                        bounds: bounds,
                        forType: .highlight,
                        withProperties: nil
                    )
                    annotation.userName = "Lectoria"
                    annotation.color = highlightColor(for: highlight.colorToken)
                    
                    firstPage.addAnnotation(annotation)
                }
            }
        }
    }
    
    private func highlightColor(for token: String) -> UIColor {
        switch token.lowercased() {
        case "idea principal", "blue", "mainidea":
            return UIColor.systemBlue.withAlphaComponent(0.3)
        case "duda", "purple", "question":
            return UIColor.systemPurple.withAlphaComponent(0.3)
        case "evidencia", "green", "evidence":
            return UIColor.systemGreen.withAlphaComponent(0.3)
        case "acción", "accion", "orange", "coral", "action":
            return UIColor.systemOrange.withAlphaComponent(0.3)
        case "cita", "pink", "quote":
            return UIColor.systemPink.withAlphaComponent(0.3)
        default:
            return UIColor.systemYellow.withAlphaComponent(0.3)
        }
    }
    
    private func updateDisplayMode(_ pdfView: PDFView) {
        if isScrollMode {
            pdfView.usePageViewController(false, withViewOptions: nil)
            pdfView.displayMode = .singlePageContinuous
            pdfView.displayDirection = .vertical
        } else {
            // Paginado horizontal suave (estilo iBooks/Kindle)
            pdfView.usePageViewController(true, withViewOptions: nil)
            pdfView.displayMode = .singlePage
            pdfView.displayDirection = .horizontal
        }
        pdfView.autoScales = true
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: PDFNavigatorWrapper
        weak var pdfView: PDFView?
        var lastTarget: PDFLocation?
        var lastHighlightsCount: Int = 0

        init(_ parent: PDFNavigatorWrapper) {
            self.parent = parent
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let pdfView = pdfView else { return }
            // Si el usuario está seleccionando texto, no alternar la interfaz
            if pdfView.currentSelection != nil {
                return
            }
            let point = gesture.location(in: pdfView)
            parent.onTap?(point)
        }

        @objc func handlePageChanged(_ notification: Notification) {
            guard let pdfView = pdfView,
                  let document = pdfView.document,
                  let currentPage = pdfView.currentPage else { return }
            
            let pageIndex = document.index(for: currentPage)
            let totalPages = document.pageCount
            
            // Publicar el cambio de ubicación
            parent.currentLocation = PDFLocation(
                pageIndex: pageIndex,
                totalPages: totalPages,
                pageLabel: currentPage.label
            )
        }

        @objc func handleSelectionChanged(_ notification: Notification) {
            guard let pdfView = pdfView else { return }
            if let selection = pdfView.currentSelection,
               let text = selection.string,
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                parent.selectedText = text
                parent.hasSelection = true
            } else {
                parent.selectedText = ""
                parent.hasSelection = false
            }
        }

        // MARK: - UIGestureRecognizerDelegate
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Permitir gestos simultáneos para no interrumpir selección ni paneo nativo de PDFView
            return true
        }
    }
}
