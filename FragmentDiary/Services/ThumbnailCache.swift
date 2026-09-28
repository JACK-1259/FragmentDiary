import Photos
import UIKit

final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSString, UIImage>()

    func image(for assetID: String, pixelSide: CGFloat) async -> UIImage? {
        let key = "\(assetID)#\(Int(pixelSide))" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard let image = await Self.load(assetID: assetID, side: pixelSide) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    @concurrent
    private nonisolated static func load(assetID: String, side: CGFloat) async -> UIImage? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil).firstObject else { return nil }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: side, height: side),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}
