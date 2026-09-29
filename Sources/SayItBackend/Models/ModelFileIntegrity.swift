import CryptoKit
import Foundation
import SayItCore

enum ModelFileIntegrity {
    static func checkReadable(_ url: URL) throws {
        let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey, .fileSizeKey])
        guard values.isSymbolicLink != true, values.isRegularFile == true,
              let size = values.fileSize, size <= ModelFilePolicy.byteLimit(for: url.path) else {
            throw ModelManagerError.incompleteSnapshot
        }
    }

    static func sha256(_ url: URL) throws -> String {
        try checkReadable(url)
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let data = try handle.read(upToCount: 1_024 * 1_024), !data.isEmpty {
            try Task.checkCancellation()
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
