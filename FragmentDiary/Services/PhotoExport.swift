import Photos
import UIKit

enum PhotoExport {
    @concurrent
    nonisolated static func jpeg(assetID: String, maxSide: CGFloat) async -> Data? {
        await image(assetID: assetID, maxSide: maxSide)?.jpegData(compressionQuality: 0.8)
    }

    @concurrent
    nonisolated static func image(assetID: String, maxSide: CGFloat) async -> UIImage? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil).firstObject else { return nil }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = true
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: maxSide, height: maxSide),
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}
