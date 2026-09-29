import Foundation

public enum ModelFilePolicy {
    public static let metadataByteLimit = 128 * 1_024 * 1_024

    public static func isSafeRelativePath(_ path: String) -> Bool {
        !path.isEmpty && !path.contains("\\") && !path.contains("\0")
            && path.split(separator: "/", omittingEmptySubsequences: false)
                .allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }

    public static func isRepository(_ value: String) -> Bool {
        value.split(separator: "/", omittingEmptySubsequences: false).count == 2
            && isSafeRelativePath(value)
            && value.utf8.allSatisfy { byte in
                (65...90).contains(byte) || (97...122).contains(byte)
                    || (48...57).contains(byte) || [45, 46, 47, 95].contains(byte)
            }
    }

    public static func isHexDigest(_ value: String, length: Int) -> Bool {
        value.utf8.count == length && value.utf8.allSatisfy {
            (48...57).contains($0) || (97...102).contains($0)
        }
    }

    public static func byteLimit(for path: String) -> Int64 {
        switch URL(filePath: path).pathExtension.lowercased() {
        case "safetensors", "npz": 32 * 1_024 * 1_024 * 1_024
        default: Int64(metadataByteLimit)
        }
    }

    public static func isValid(_ file: ModelFileDescriptor) -> Bool {
        isSafeRelativePath(file.path) && file.byteCount > 0
            && file.byteCount <= byteLimit(for: file.path)
            && (file.sha256.map { isHexDigest($0, length: 64) } == true
                || file.gitBlobSHA1.map { isHexDigest($0, length: 40) } == true)
    }
}
