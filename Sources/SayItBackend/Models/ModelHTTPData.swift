import Foundation
import SayItCore

enum ModelHTTPData {
    static func read(session: URLSession, request: URLRequest) async throws -> (Data, URLResponse) {
        let (bytes, response) = try await session.bytes(for: request)
        let limit = ModelFilePolicy.metadataByteLimit
        guard response.expectedContentLength <= limit else {
            throw URLError(.dataLengthExceedsMaximum)
        }
        var data = Data()
        for try await byte in bytes {
            guard data.count < limit else { throw URLError(.dataLengthExceedsMaximum) }
            data.append(byte)
        }
        return (data, response)
    }
}
