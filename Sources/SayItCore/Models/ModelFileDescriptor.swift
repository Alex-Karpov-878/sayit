import Foundation

public struct ModelFileDescriptor: Codable, Equatable, Sendable {
    public let path: String
    public let byteCount: Int64
    public let sha256: String?
    public let gitBlobSHA1: String?

    public init(path: String, byteCount: Int64, sha256: String?, gitBlobSHA1: String? = nil) {
        self.path = path
        self.byteCount = byteCount
        self.sha256 = sha256
        self.gitBlobSHA1 = gitBlobSHA1
    }
}
