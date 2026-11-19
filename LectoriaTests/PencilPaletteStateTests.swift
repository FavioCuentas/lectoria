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
        #expect(PencilPaletteState(publicationType: .pdf, defaults: defaults).availableTools == [.text, .pen, .marker, .eraser])
        #expect(PencilPaletteState(publicationType: .pptx, defaults: defaults).availableTools == [.text, .pen, .marker, .eraser])
        #expect(PencilPaletteState(publicationType: .epub, defaults: defaults).availableTools == [.text])
        #expect(PencilPaletteState(publicationType: .txt, defaults: defaults).availableTools == [.text])
    }

    @Test func testDefaults() {
        let state = PencilPaletteState(publicationType: .pdf, defaults: makeDefaults())
        #expect(state.tool == .text)
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

    @Test func testUnavailableSavedToolFallsBackToText() {
        let defaults = makeDefaults()
        PencilPaletteState(publicationType: .pdf, defaults: defaults).tool = .pen
        #expect(PencilPaletteState(publicationType: .epub, defaults: defaults).tool == .text)
    }

    @Test func testStrokeWidths() {
        let state = PencilPaletteState(publicationType: .pdf, defaults: makeDefaults())
        state.tool = .pen
        state.width = .medium
        #expect(state.strokeWidth() == 4)
        state.tool = .marker
        state.width = .thick
        #expect(state.strokeWidth() == 30)
        state.tool = .text
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
