import Foundation
import Testing
@testable import SayItBackend

struct ModelNetworkPolicyTests {
    @Test("Unmanaged library traffic is rejected before reaching the transport")
    func blocksFallback() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UnmanagedModelRequest.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let request = URLRequest(url: URL(string: "https://should-never-resolve.invalid/model")!)
        #expect(UnmanagedModelRequest.canInit(with: request))
        #expect(!UnmanagedModelRequest.canInit(with: ModelNetworkPolicy.authorize(request)))
        do {
            _ = try await session.data(for: request)
            Issue.record("Unmanaged request escaped")
        } catch {
            #expect((error as NSError).domain == "SayIt.ModelNetworkPolicy")
        }
    }
}
