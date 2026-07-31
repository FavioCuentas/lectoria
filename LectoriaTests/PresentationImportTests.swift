import Testing
import Foundation
import CoreGraphics
@testable import Lectoria

struct PresentationImportTests {

    @Test func testPresentationFormatDetection() async throws {
        let extensions = ["pptx", "ppt", "pps", "ppsx", "key", "odp"]
        for ext in extensions {
            let pubType = PublicationType.from(fileExtension: ext)
            #expect(pubType == .pptx)
        }
    }

    @Test func testPresentationFormatEnumMapping() async throws {
        #expect(PresentationFormat(fileExtension: "pptx") == .pptx)
        #expect(PresentationFormat(fileExtension: "ppt") == .ppt)
        #expect(PresentationFormat(fileExtension: "pps") == .pps)
        #expect(PresentationFormat(fileExtension: "ppsx") == .ppsx)
        #expect(PresentationFormat(fileExtension: "key") == .key)
        #expect(PresentationFormat(fileExtension: "odp") == .odp)
        #expect(PresentationFormat(fileExtension: "pdf") == .pdf)
    }

    @Test func testRenderedSlideDescriptorAspectRatio() async throws {
        let descriptor16x9 = RenderedSlideDescriptor(
            id: SlideID("slide-1"),
            index: 0,
            canvasSize: CGSize(width: 1920, height: 1080),
            aspectRatio: 16.0 / 9.0
        )
        #expect(abs(descriptor16x9.aspectRatio - 1.7777777777777777) < 0.001)

        let descriptor4x3 = RenderedSlideDescriptor(
            id: SlideID("slide-2"),
            index: 1,
            canvasSize: CGSize(width: 1024, height: 768),
            aspectRatio: 0
        )
        #expect(abs(descriptor4x3.aspectRatio - 1.3333333333333333) < 0.001)
    }

    @Test func testPresentationRenderManifest() async throws {
        let original = URL(fileURLWithPath: "/tmp/sample.pptx")
        let slides = [
            RenderedSlideDescriptor(id: SlideID("1"), index: 0, canvasSize: CGSize(width: 1920, height: 1080), aspectRatio: 16/9),
            RenderedSlideDescriptor(id: SlideID("2"), index: 1, canvasSize: CGSize(width: 1920, height: 1080), aspectRatio: 16/9)
        ]
        let manifest = PresentationRenderManifest(
            originalURL: original,
            derivedURL: nil,
            format: .pptx,
            slideCount: slides.count,
            slides: slides,
            fidelityWarnings: [.animationsIgnored]
        )

        #expect(manifest.slideCount == 2)
        #expect(manifest.slides.count == 2)
        #expect(manifest.format == .pptx)
        #expect(manifest.fidelityWarnings.contains(.animationsIgnored))
    }
}
