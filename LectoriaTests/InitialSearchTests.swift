import Testing
import Foundation
@testable import Lectoria

struct InitialSearchTests {
    @Test func testResolverPrefersScope() {
        let scopes = ["0", "2", "2", "5"]
        #expect(InitialSearchResolver.firstMatchIndex(in: scopes, scope: "2", scopeOf: { $0 }) == 1)
    }

    @Test func testResolverFallsBackToFirst() {
        #expect(InitialSearchResolver.firstMatchIndex(in: ["0", "2"], scope: "9", scopeOf: { $0 }) == 0)
        #expect(InitialSearchResolver.firstMatchIndex(in: ["0", "2"], scope: nil, scopeOf: { $0 }) == 0)
    }

    @Test func testResolverEmptyIsNil() {
        #expect(InitialSearchResolver.firstMatchIndex(in: [String](), scope: "0", scopeOf: { $0 }) == nil)
    }

    @Test func testHrefScopeIgnoresFragment() {
        #expect(InitialSearchKey.normalizedHref("OEBPS/ch2.xhtml#p3") == "OEBPS/ch2.xhtml")
        #expect(InitialSearchKey.normalizedHref("ch2.xhtml") == "ch2.xhtml")
    }

    @Test func testTextResolverPicksFirstAtOrAfterBlock() {
        let blocks = [0, 3, 8, 12]
        #expect(InitialSearchResolver.firstIndex(in: blocks, atOrAfter: 5, blockOf: { $0 }) == 2)
        #expect(InitialSearchResolver.firstIndex(in: blocks, atOrAfter: 20, blockOf: { $0 }) == 0)
        #expect(InitialSearchResolver.firstIndex(in: [Int](), atOrAfter: 0, blockOf: { $0 }) == nil)
    }
}
