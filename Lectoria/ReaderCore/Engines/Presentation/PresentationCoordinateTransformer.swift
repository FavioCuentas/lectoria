import Foundation
import CoreGraphics

// MARK: - PresentationCoordinateTransformer

/// Transformador geométrico inmutable para proyectar coordenadas entre la diapositiva original
/// en coordenadas normalizadas `(0...1)` y el espacio de coordenadas de pantalla del visor (`viewCoordinates`).
///
/// Garantiza la preservación estricta de la relación de aspecto (`aspectFit`), letterboxing, zoom
/// y escalado uniforme sin desalineación de anotaciones al rotar o ajustar la ventana.
public struct PresentationCoordinateTransformer: Sendable {
    public let canvasSize: CGSize

    public init(canvasSize: CGSize) {
        self.canvasSize = canvasSize.width > 0 && canvasSize.height > 0
            ? canvasSize
            : CGSize(width: 1920, height: 1080)
    }

    /// Calcula la escala de ajuste proporcional `aspectFit` dada una vista contenedora.
    public func aspectFitScale(in viewSize: CGSize) -> CGFloat {
        guard viewSize.width > 0, viewSize.height > 0 else { return 1.0 }
        let scaleX = viewSize.width / canvasSize.width
        let scaleY = viewSize.height / canvasSize.height
        return min(scaleX, scaleY)
    }

    /// Calcula el marco rectangular ajustado (`fittedRect`) del slide en la vista.
    public func fittedRect(in viewSize: CGSize, zoomScale: CGFloat = 1.0, scrollOffset: CGPoint = .zero) -> CGRect {
        let baseScale = aspectFitScale(in: viewSize)
        let effectiveScale = baseScale * max(0.1, zoomScale)

        let fittedWidth = canvasSize.width * effectiveScale
        let fittedHeight = canvasSize.height * effectiveScale

        let originX = ((viewSize.width - fittedWidth) / 2.0) + scrollOffset.x
        let originY = ((viewSize.height - fittedHeight) / 2.0) + scrollOffset.y

        return CGRect(x: originX, y: originY, width: fittedWidth, height: fittedHeight)
    }

    /// Convierte un punto normalizado de la diapositiva `(0...1, 0...1)` a coordenadas de pantalla (`viewCoordinates`).
    public func slideToView(
        normalizedPoint: CGPoint,
        in viewSize: CGSize,
        zoomScale: CGFloat = 1.0,
        scrollOffset: CGPoint = .zero
    ) -> CGPoint {
        let rect = fittedRect(in: viewSize, zoomScale: zoomScale, scrollOffset: scrollOffset)
        let x = rect.origin.x + (normalizedPoint.x * rect.width)
        let y = rect.origin.y + (normalizedPoint.y * rect.height)
        return CGPoint(x: x, y: y)
    }

    /// Convierte un punto de la pantalla (`viewCoordinates`) a un punto normalizado `(0...1, 0...1)` en la diapositiva.
    public func viewToSlide(
        viewPoint: CGPoint,
        in viewSize: CGSize,
        zoomScale: CGFloat = 1.0,
        scrollOffset: CGPoint = .zero
    ) -> CGPoint {
        let rect = fittedRect(in: viewSize, zoomScale: zoomScale, scrollOffset: scrollOffset)
        guard rect.width > 0, rect.height > 0 else { return CGPoint(x: 0.5, y: 0.5) }

        let rawX = (viewPoint.x - rect.origin.x) / rect.width
        let rawY = (viewPoint.y - rect.origin.y) / rect.height

        let clampedX = min(max(rawX, 0.0), 1.0)
        let clampedY = min(max(rawY, 0.0), 1.0)

        return CGPoint(x: clampedX, y: clampedY)
    }
}
