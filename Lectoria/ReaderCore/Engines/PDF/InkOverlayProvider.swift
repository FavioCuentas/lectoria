import UIKit
import PDFKit
import PencilKit
import os

private let logger = Logger(subsystem: "com.orvexa.Lectoria", category: "Ink")

// MARK: - InkOverlayProvider

/// Trazo libre con el Pencil sobre las páginas del PDF (pluma, marcador y borrador; solo iPad).
///
/// Cada página visible tiene un `PKCanvasView` transparente encima. Los dibujos se guardan en el
/// tamaño de la página (no del lienzo), así siguen en su sitio con zoom, giro o cambio de tamaño.
@MainActor
final class InkOverlayProvider: NSObject, PDFPageOverlayViewProvider, PKCanvasViewDelegate {
    private let publicationID: UUID
    private let store: InkStore
    private weak var document: PDFDocument?

    /// Dibujos por índice de página, en coordenadas de página.
    private var drawings: [Int: PKDrawing] = [:]
    /// Lienzo más reciente de cada página (para mostrar los dibujos al terminar de cargar).
    private var canvases: [Int: InkCanvasView] = [:]
    /// Todos los lienzos en pantalla. PDFKit puede pedir otro lienzo para una página antes de retirar
    /// el anterior: la herramienta se aplica a todos para que ninguno quede activo con la paleta oculta.
    private let liveCanvases = NSHashTable<InkCanvasView>.weakObjects()
    private var pendingSaves: [Int: Task<Void, Never>] = [:]

    private var tool: PencilTool?
    private var color: UIColor = .black
    private var width: CGFloat = 4

    init(publicationID: UUID, document: PDFDocument, store: InkStore = .shared) {
        self.publicationID = publicationID
        self.document = document
        self.store = store
    }

    /// Carga los dibujos guardados y los muestra en las páginas ya visibles.
    func loadDrawings() async {
        let stored = await store.drawings(for: publicationID)
        var loaded: [Int: PKDrawing] = [:]
        for (page, data) in stored {
            do { loaded[page] = try PKDrawing(data: data) } catch {
                logger.error("Dibujo ilegible en la página \(page): \(String(describing: error))")
            }
        }
        // Lo dibujado mientras cargaba tiene prioridad.
        drawings = loaded.merging(drawings) { _, current in current }
        for canvas in liveCanvases.allObjects {
            canvas.setPageDrawing(drawings[canvas.pageIndex] ?? PKDrawing())
        }
    }

    /// Herramienta actual. Solo pluma, marcador y borrador hacen el lienzo interactivo.
    func apply(tool: PencilTool?, color: UIColor, width: CGFloat) {
        let wasDrawing = Self.isInkTool(self.tool)
        self.tool = tool
        self.color = color
        self.width = width
        liveCanvases.allObjects.forEach(configure)
        if wasDrawing && !Self.isInkTool(tool) { flushSaves() }
    }

    static func isInkTool(_ tool: PencilTool?) -> Bool {
        tool == .pen || tool == .marker || tool == .eraser
    }

    // MARK: PDFPageOverlayViewProvider

    func pdfView(_ view: PDFView, overlayViewFor page: PDFPage) -> UIView? {
        guard let index = document?.index(for: page), index != NSNotFound else { return nil }
        // Un lienzo nuevo por cada vista de página: nunca se reutiliza uno que puede seguir en pantalla.
        let canvas = InkCanvasView(pageIndex: index, pageSize: page.bounds(for: view.displayBox).size)
        canvas.delegate = self
        canvas.setPageDrawing(drawings[index] ?? PKDrawing())
        configure(canvas)
        canvases[index] = canvas
        liveCanvases.add(canvas)
        return canvas
    }

    func pdfView(_ pdfView: PDFView, willEndDisplayingOverlayView overlayView: UIView, for page: PDFPage) {
        guard let canvas = overlayView as? InkCanvasView else { return }
        // Solo se guarda si la página tiene cambios: así desplazarse no reescribe el archivo
        // ni puede borrar dibujos guardados que aún no terminaban de cargar.
        if pendingSaves[canvas.pageIndex] != nil { saveNow(page: canvas.pageIndex) }
        if canvases[canvas.pageIndex] === canvas { canvases[canvas.pageIndex] = nil }
        liveCanvases.remove(canvas)
    }

    // MARK: PKCanvasViewDelegate

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        guard let canvas = canvasView as? InkCanvasView, !canvas.isApplyingDrawing else { return }
        drawings[canvas.pageIndex] = canvas.pageDrawing()
        scheduleSave(page: canvas.pageIndex)
    }

    // MARK: Guardado

    private func scheduleSave(page: Int) {
        pendingSaves[page]?.cancel()
        pendingSaves[page] = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.saveNow(page: page)
        }
    }

    private func saveNow(page: Int) {
        pendingSaves[page]?.cancel()
        pendingSaves[page] = nil
        let drawing = drawings[page]
        let data = (drawing?.strokes.isEmpty ?? true) ? nil : drawing?.dataRepresentation()
        let store = store, id = publicationID
        Task {
            do { try await store.save(data, page: page, publicationID: id) } catch {
                logger.error("No se pudo guardar el dibujo de la página \(page): \(String(describing: error))")
            }
        }
    }

    /// Guarda todo lo pendiente (al cambiar de herramienta, ocultar la paleta o cerrar el lector).
    func flushSaves() {
        for page in Array(pendingSaves.keys) { saveNow(page: page) }
    }

    private func configure(_ canvas: InkCanvasView) {
        switch tool {
        case .pen: canvas.tool = PKInkingTool(.pen, color: color, width: width)
        case .marker: canvas.tool = PKInkingTool(.marker, color: color, width: width)
        case .eraser: canvas.tool = PKEraserTool(.vector)
        case nil: break
        }
        canvas.isUserInteractionEnabled = Self.isInkTool(tool)
    }
}

// MARK: - InkCanvasView

/// Lienzo de una página. Guarda el dibujo en tamaño de página y lo escala al tamaño visible.
final class InkCanvasView: PKCanvasView {
    let pageIndex: Int
    private let pageSize: CGSize
    private var normalized = PKDrawing()
    private var appliedScale: CGFloat = 0
    /// Mientras se asigna el dibujo por código no hay que tratarlo como un trazo del usuario.
    private(set) var isApplyingDrawing = false

    init(pageIndex: Int, pageSize: CGSize) {
        self.pageIndex = pageIndex
        self.pageSize = pageSize
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
        drawingPolicy = .pencilOnly
        isScrollEnabled = false
        // Los colores del trazo no deben invertirse en modo oscuro.
        overrideUserInterfaceStyle = .light
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) no se usa") }

    private var scale: CGFloat {
        guard pageSize.width > 0, bounds.width > 0 else { return 1 }
        return bounds.width / pageSize.width
    }

    func setPageDrawing(_ drawing: PKDrawing) {
        normalized = drawing
        applyScaledDrawing()
    }

    func pageDrawing() -> PKDrawing {
        normalized = drawing.transformed(using: CGAffineTransform(scaleX: 1 / scale, y: 1 / scale))
        return normalized
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if abs(scale - appliedScale) > 0.0001 { applyScaledDrawing() }
    }

    private func applyScaledDrawing() {
        let scale = scale
        appliedScale = scale
        isApplyingDrawing = true
        drawing = normalized.transformed(using: CGAffineTransform(scaleX: scale, y: scale))
        isApplyingDrawing = false
    }
}
