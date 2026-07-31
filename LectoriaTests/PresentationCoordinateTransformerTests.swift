import Testing
import Foundation
import CoreGraphics
@testable import Lectoria

struct PresentationCoordinateTransformerTests {

    @Test func testAspectFitScaleCalculation() async throws {
        let transformer16x9 = PresentationCoordinateTransformer(canvasSize: CGSize(width: 1920, height: 1080))
        let viewSize = CGSize(width: 390, height: 844) // iPhone viewport

        let scale = transformer16x9.aspectFitScale(in: viewSize)
        // 390 / 1920 = 0.203125, 844 / 1080 = 0.781481
        #expect(abs(scale - 0.203125) < 0.0001)
    }

    @Test func testFittedRectCentering() async throws {
        let transformer = PresentationCoordinateTransformer(canvasSize: CGSize(width: 1000, height: 500))
        let viewSize = CGSize(width: 1000, height: 1000)

        let rect = transformer.fittedRect(in: viewSize)
        #expect(rect.width == 1000)
        #expect(rect.height == 500)
        #expect(rect.origin.x == 0)
        #expect(rect.origin.y == 250) // Vertically centered letterboxing
    }

    @Test func testSlideToViewAndInverseTransformation() async throws {
        let transformer = PresentationCoordinateTransformer(canvasSize: CGSize(width: 1920, height: 1080))
        let viewSize = CGSize(width: 1000, height: 800)

        let originalSlidePoint = CGPoint(x: 0.25, y: 0.75)
        let viewPoint = transformer.slideToView(normalizedPoint: originalSlidePoint, in: viewSize, zoomScale: 1.5)
        let recoveredSlidePoint = transformer.viewToSlide(viewPoint: viewPoint, in: viewSize, zoomScale: 1.5)

        #expect(abs(recoveredSlidePoint.x - originalSlidePoint.x) < 0.0001)
        #expect(abs(recoveredSlidePoint.y - originalSlidePoint.y) < 0.0001)
    }

    @Test func testClampingViewToSlideCoordinates() async throws {
        let transformer = PresentationCoordinateTransformer(canvasSize: CGSize(width: 1000, height: 1000))
        let viewSize = CGSize(width: 1000, height: 1000)

        // Point outside the slide area
        let outsidePoint = CGPoint(x: -200, y: 1500)
        let clamped = transformer.viewToSlide(viewPoint: outsidePoint, in: viewSize)

        #expect(clamped.x == 0.0)
        #expect(clamped.y == 1.0)
    }
}
