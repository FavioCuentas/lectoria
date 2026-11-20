import Testing
import UIKit
@testable import Lectoria

@MainActor
struct PencilPaletteStateTests {
    private func makeDefaults() -> UserDefaults {
        let name = "PencilPaletteTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func testToolsPerFormat() {
        let defaults = makeDefaults()
        #expect(PencilPaletteState(publicationType: .pdf, defaults: defaults).availableTools == [.pen, .marker, .eraser])
        #expect(PencilPaletteState(publicationType: .pptx, defaults: defaults).availableTools == [.pen, .marker, .eraser])
        #expect(PencilPaletteState(publicationType: .epub, defaults: defaults).availableTools == [.marker, .eraser])
        #expect(PencilPaletteState(publicationType: .txt, defaults: defaults).availableTools == [.marker, .eraser])
        #expect(PencilPaletteState(publicationType: .markdown, defaults: defaults).availableTools == [.marker, .eraser])
    }

    /// En texto el marcador sigue las palabras o párrafos: no tiene grosor.
    @Test func testWidthOnlyForFixedLayout() {
        let defaults = makeDefaults()
        #expect(PencilPaletteState(publicationType: .pdf, defaults: defaults).showsWidth)
        #expect(!PencilPaletteState(publicationType: .epub, defaults: defaults).showsWidth)
        #expect(!PencilPaletteState(publicationType: .txt, defaults: defaults).showsWidth)
    }

    /// Una pluma guardada (PDF) no existe en EPUB: arranca con el marcador.
    @Test func testPenFallsBackToMarkerInTextFormats() {
        let defaults = makeDefaults()
        PencilPaletteState(publicationType: .pdf, defaults: defaults).tool = .pen
        #expect(PencilPaletteState(publicationType: .epub, defaults: defaults).tool == .marker)
    }

    @Test func testDefaults() {
        let state = PencilPaletteState(publicationType: .pdf, defaults: makeDefaults())
        #expect(state.tool == .pen)
        #expect(state.category == .mainIdea)
        #expect(state.penColor == .category(.mainIdea))
        #expect(state.width == .medium)
    }

    @Test func testPersistsAcrossInstances() {
        let defaults = makeDefaults()
        let state = PencilPaletteState(publicationType: .pdf, defaults: defaults)
        state.tool = .pen
        state.penColor = .black
        state.width = .thick
        state.category = .question

        let restored = PencilPaletteState(publicationType: .pdf, defaults: defaults)
        #expect(restored.tool == .pen)
        #expect(restored.penColor == .black)
        #expect(restored.width == .thick)
        #expect(restored.category == .question)
    }

    /// La herramienta Texto se quitó: una preferencia antigua con "text" vuelve a la pluma.
    @Test func testLegacyTextToolFallsBackToPen() {
        let defaults = makeDefaults()
        defaults.set("text", forKey: "pencil.tool")
        #expect(PencilPaletteState(publicationType: .pdf, defaults: defaults).tool == .pen)
    }

    @Test func testStrokeWidths() {
        let state = PencilPaletteState(publicationType: .pdf, defaults: makeDefaults())
        state.tool = .pen
        state.width = .medium
        #expect(state.strokeWidth() == 4)
        state.tool = .marker
        state.width = .thick
        #expect(state.strokeWidth() == 30)
        state.tool = .eraser
        #expect(state.strokeWidth() == 0)
    }

    @Test func testMarkerColorIsTranslucent() {
        let state = PencilPaletteState(publicationType: .pdf, defaults: makeDefaults())
        var alpha: CGFloat = 0
        state.tool = .marker
        state.inkColor().getRed(nil, green: nil, blue: nil, alpha: &alpha)
        #expect(abs(alpha - 0.35) < 0.001)
        state.tool = .pen
        state.inkColor().getRed(nil, green: nil, blue: nil, alpha: &alpha)
        #expect(alpha == 1)
    }
}
