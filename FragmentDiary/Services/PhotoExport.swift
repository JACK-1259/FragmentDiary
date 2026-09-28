import Photos
import UIKit

enum PhotoExport {
    @concurrent
    nonisolated static func jpeg(assetID: String, maxSide: CGFloat) async -> Data? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil).firstObject else { return nil }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = true
        let image: UIImage? = await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: maxSide, height: maxSide),
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
        return image?.jpegData(compressionQuality: 0.8)
    }
}
