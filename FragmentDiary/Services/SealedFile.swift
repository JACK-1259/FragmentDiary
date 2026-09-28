import CryptoKit
import Foundation

/// AES-GCM sealed files with iOS complete file protection on top.
enum SealedFile {
    enum SealError: LocalizedError {
        case sealFailed

        var errorDescription: String? { "기록을 암호화하지 못했어요." }
    }

    static func read<T: Decodable>(_ type: T.Type, from url: URL, key: SymmetricKey) throws -> T? {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return nil }
        return try JSONDecoder().decode(type, from: readData(from: url, key: key))
    }

    static func write(_ value: some Encodable, to url: URL, key: SymmetricKey) throws {
        try writeData(JSONEncoder().encode(value), to: url, key: key)
    }

    static func readData(from url: URL, key: SymmetricKey) throws -> Data {
        try AES.GCM.open(AES.GCM.SealedBox(combined: Data(contentsOf: url)), using: key)
    }

    static func writeData(_ data: Data, to url: URL, key: SymmetricKey) throws {
        guard let sealed = try AES.GCM.seal(data, using: key).combined else { throw SealError.sealFailed }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try sealed.write(to: url, options: [.atomic, .completeFileProtection])
    }
}
