import Foundation

/// Disable incidental URLSession downloads by inference libraries. Only the
/// application's reviewed metadata/download requests opt in. This is a guard
/// against upstream fallback behavior, not a sandbox for hostile native code.
public enum ModelNetworkPolicy {
    public static func install() -> Bool {
        URLProtocol.registerClass(UnmanagedModelRequest.self)
    }

    static func authorize(_ request: URLRequest) -> URLRequest {
        guard let mutable = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            return request // Unmarked requests remain blocked.
        }
        URLProtocol.setProperty(true, forKey: UnmanagedModelRequest.authorizationKey, in: mutable)
        return mutable as URLRequest
    }
}

final class UnmanagedModelRequest: URLProtocol, @unchecked Sendable {
    static let authorizationKey = "sh.sayit.reviewed-model-request"

    override class func canInit(with request: URLRequest) -> Bool {
        guard let scheme = request.url?.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            return false
        }
        return URLProtocol.property(forKey: authorizationKey, in: request) as? Bool != true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: NSError(
            domain: "SayIt.ModelNetworkPolicy", code: 1,
            userInfo: [NSLocalizedDescriptionKey:
                "An unmanaged model download was blocked. Install or repair the model in Settings."]
        ))
    }

    override func stopLoading() {}
}
