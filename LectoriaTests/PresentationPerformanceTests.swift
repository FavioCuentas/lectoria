import Testing
import Foundation
import UIKit
@testable import Lectoria

struct PresentationPerformanceTests {

    @Test func testThumbnailMemoryCacheStorageAndRetrieval() async throws {
        let cache = PresentationCacheManager.shared
        let cacheKey = "slide_thumb_test_\(UUID().uuidString)"

        // Generate a 100x100 test image
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        let testImage = renderer.image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }

        cache.cacheThumbnail(testImage, for: cacheKey)
        let retrieved = cache.cachedThumbnail(for: cacheKey)

        #expect(retrieved != nil)
        #expect(retrieved?.size.width == 100)
    }

    @Test func testMemoryCachePurging() async throws {
        let cache = PresentationCacheManager.shared
        let cacheKey = "purge_key_\(UUID().uuidString)"

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 50, height: 50))
        let testImage = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 50, height: 50))
        }

        cache.cacheThumbnail(testImage, for: cacheKey)
        #expect(cache.cachedThumbnail(for: cacheKey) != nil)

        cache.clearMemoryCache()
        #expect(cache.cachedThumbnail(for: cacheKey) == nil)
    }
}
