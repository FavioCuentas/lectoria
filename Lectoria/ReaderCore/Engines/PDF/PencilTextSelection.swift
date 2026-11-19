import PDFKit

// MARK: - PencilTextSelection

/// Convierte un trazo del Pencil (inicio y fin, en coordenadas de página) en una selección de texto.
///
/// Los puntos se ajustan a la línea de texto más cercana, para que un trazo que empieza o termina
/// en el margen seleccione igualmente lo que cruza. Si el trazo no pasa cerca de texto, no hay selección.
enum PencilTextSelection {
    /// Líneas de texto de la página. Se pueden calcular una vez por trazo y reutilizar.
    static func lines(on page: PDFPage) -> [CGRect] {
        guard let all = page.selection(for: page.bounds(for: .mediaBox)) else { return [] }
        return all.selectionsByLine()
            .filter { !($0.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { $0.bounds(for: page) }
            .filter { !$0.isEmpty }
    }

    static func selection(on page: PDFPage, from start: CGPoint, to end: CGPoint, lines: [CGRect]? = nil) -> PDFSelection? {
        let lines = lines ?? Self.lines(on: page)
        guard let first = snap(start, to: lines), let last = snap(end, to: lines) else { return nil }
        // Ordenar en orden de lectura (arriba→abajo, izquierda→derecha) para que el trazo funcione en ambos sentidos.
        let (from, to) = isBefore(first, last) ? (first, last) : (last, first)
        guard let selection = page.selection(from: from, to: to),
              let text = selection.string,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return selection
    }

    /// Lleva el punto dentro de la línea más cercana, o `nil` si no hay ninguna lo bastante cerca.
    private static func snap(_ point: CGPoint, to lines: [CGRect]) -> CGPoint? {
        let nearest = lines.min { distance(point, $0) < distance(point, $1) }
        guard let line = nearest else { return nil }
        let tolerance = max(line.height, 12)
        guard abs(point.y - line.midY) <= tolerance else { return nil }
        let x = min(max(point.x, line.minX + 0.5), line.maxX - 0.5)
        return CGPoint(x: x, y: line.midY)
    }

    private static func distance(_ point: CGPoint, _ rect: CGRect) -> CGFloat {
        let dy = abs(point.y - rect.midY)
        let dx = point.x < rect.minX ? rect.minX - point.x : (point.x > rect.maxX ? point.x - rect.maxX : 0)
        return dy * 4 + dx // la distancia vertical pesa más: el trazo suele seguir la línea
    }

    /// En coordenadas de PDF la y crece hacia arriba: una línea más alta va antes.
    private static func isBefore(_ a: CGPoint, _ b: CGPoint) -> Bool {
        if abs(a.y - b.y) > 1 { return a.y > b.y }
        return a.x <= b.x
    }
}
