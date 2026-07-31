import SwiftUI

// MARK: - SlideAnnotationPin

/// Representa la posición normalizada de un pin de nota sobre una diapositiva.
public struct SlideAnnotationPin: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let slideIndex: Int
    public let normalizedPoint: CGPoint
    public let category: StudyCategory
    public let noteText: String

    public init(
        id: UUID = UUID(),
        slideIndex: Int,
        normalizedPoint: CGPoint,
        category: StudyCategory = .importante,
        noteText: String
    ) {
        self.id = id
        self.slideIndex = slideIndex
        self.normalizedPoint = normalizedPoint
        self.category = category
        self.noteText = noteText
    }
}

// MARK: - PresentationAnnotationOverlayView

/// Capa transparente superpuesta sobre el lienzo de la diapositiva que proyecta pines de notas y resaltados
/// manteniendo alineación bidireccional mediante `PresentationCoordinateTransformer`.
struct PresentationAnnotationOverlayView: View {
    let pins: [SlideAnnotationPin]
    let canvasSize: CGSize
    let onSelectPin: (SlideAnnotationPin) -> Void

    var body: some View {
        GeometryReader { geometry in
            let transformer = PresentationCoordinateTransformer(canvasSize: canvasSize)

            ForEach(pins) { pin in
                let viewPoint = transformer.slideToView(
                    normalizedPoint: pin.normalizedPoint,
                    in: geometry.size
                )

                Button {
                    onSelectPin(pin)
                } label: {
                    ZStack {
                        Circle()
                            .fill(pin.category.color)
                            .frame(width: 24, height: 24)
                            .shadow(radius: 2)

                        Image(systemName: pin.category.iconName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .position(viewPoint)
                .accessibilityLabel("Pin de nota \(pin.category.rawValue) en diapositiva")
            }
        }
    }
}
