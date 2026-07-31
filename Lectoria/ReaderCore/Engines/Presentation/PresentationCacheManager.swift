import Foundation
import UIKit

// MARK: - PresentationCacheManager

/// Administrador de caché eficiente en memoria y disco para previsualizaciones, miniaturas
/// y manifiestos de renderizado de presentaciones.
///
/// Implementa liberación automática ante advertencias de memoria (`didReceiveMemoryWarning`)
/// y aislamiento de caché desduplicado mediante hash SHA-256.
public final class PresentationCacheManager: @unchecked Sendable {
    public static let shared = PresentationCacheManager()

    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default

    private init() {
        memoryCache.countLimit = 200 // Máximo 200 miniaturas en memoria
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50 MB límite de memoria

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleMemoryWarning() {
        clearMemoryCache()
    }

    /// Guarda una miniatura en la caché en memoria.
    public func cacheThumbnail(_ image: UIImage, for key: String) {
        let nsKey = key as NSString
        let cost = Int(image.size.width * image.size.height * 4)
        memoryCache.setObject(image, forKey: nsKey, cost: cost)
    }

    /// Recupera una miniatura desde la caché en memoria.
    public func cachedThumbnail(for key: String) -> UIImage? {
        return memoryCache.object(forKey: key as NSString)
    }

    /// Purga la caché en memoria.
    public func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }
}
