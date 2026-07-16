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
        
        // Registrar observación de cambio de página
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.handlePageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )
        
        // Ir a la página inicial si existe
        if let initial = initialLocation,
           let page = document.page(at: initial.pageIndex) {
            pdfView.go(to: page)
        }
        
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

        // MARK: - UIGestureRecognizerDelegate
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Permitir gestos simultáneos para no interrumpir selección ni paneo nativo de PDFView
            return true
        }
    }
}
