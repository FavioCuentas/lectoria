import SwiftUI
import UIKit

// MARK: - PencilStrokeRecognizer

/// Arrastre que solo acepta el Apple Pencil. Mientras está activo, los demás gestos de la vista
/// (desplazar, seleccionar) esperan a que falle: un trazo del lápiz marca y no desplaza, pero un toque
/// del lápiz sin arrastrar y cualquier gesto con el dedo funcionan como siempre.
final class PencilStrokeRecognizer: UIPanGestureRecognizer, UIGestureRecognizerDelegate {
    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        allowedTouchTypes = [NSNumber(value: UITouch.TouchType.pencil.rawValue)]
        maximumNumberOfTouches = 1
        delegate = self
        isEnabled = false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        otherGestureRecognizer !== self
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    /// Punto donde tocó el lápiz: al reconocerse, la posición ya avanzó el umbral del arrastre.
    func startLocation(in view: UIView?) -> CGPoint {
        let location = location(in: view)
        let translation = translation(in: view)
        return CGPoint(x: location.x - translation.x, y: location.y - translation.y)
    }
}

// MARK: - PencilStrokeGesture

/// El mismo trazo del lápiz para vistas SwiftUI, con puntos en el espacio de coordenadas indicado.
struct PencilStrokeGesture: UIGestureRecognizerRepresentable {
    var isEnabled: Bool
    var coordinateSpaceName: String
    var onChanged: (_ start: CGPoint, _ current: CGPoint) -> Void
    var onEnded: (_ start: CGPoint, _ end: CGPoint) -> Void

    final class Coordinator {
        var start: CGPoint = .zero
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> PencilStrokeRecognizer {
        let recognizer = PencilStrokeRecognizer(target: nil, action: nil)
        recognizer.isEnabled = isEnabled
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: PencilStrokeRecognizer, context: Context) {
        recognizer.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(_ recognizer: PencilStrokeRecognizer, context: Context) {
        let space = NamedCoordinateSpace.named(coordinateSpaceName)
        let current = context.converter.location(in: space)
        switch recognizer.state {
        case .began:
            let translation = recognizer.translation(in: recognizer.view)
            context.coordinator.start = CGPoint(x: current.x - translation.x, y: current.y - translation.y)
            onChanged(context.coordinator.start, current)
        case .changed:
            onChanged(context.coordinator.start, current)
        case .ended:
            onEnded(context.coordinator.start, current)
        default:
            break
        }
    }
}
