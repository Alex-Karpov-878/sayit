import Foundation
import SayItCore
import Testing
@testable import SayItBackend

@Suite("Speech routing")
struct RoutingSpeechSynthesizerTests {
    @Test("Local requests never leave the Mac even if remote mode changes")
    func localRequestStaysLocal() async throws {
        let local = RoutingLocalFixture()
        let remote = OpenAICompatibleSpeechSynthesizer(
            apiKeyProvider: { _ in nil },
            session: { _ in
                Issue.record("A local request reached the network")
                throw URLError(.badURL)
            }
        )
        let router = RoutingSpeechSynthesizer(local: local, remote: remote)
        await router.updateRemoteConfiguration(.init(
            enabled: true, baseURL: URL(string: "https://example.invalid"),
            model: "remote", voice: "test", timeoutSeconds: 5
        ))
        let model = try #require(ModelCatalogLoader().bundledCatalog().models.first)
        let request = try await request(model: model)
        for try await _ in await router.synthesize(request) {}
        #expect(await local.requestCount == 1)
    }

    @Test("Remote failures never fall back to an unrelated local voice")
    func noSilentFallback() async throws {
        let local = RoutingLocalFixture()
        let remote = OpenAICompatibleSpeechSynthesizer(
            apiKeyProvider: { _ in nil }, session: { _ in throw URLError(.cannotConnectToHost) }
        )
        let router = RoutingSpeechSynthesizer(local: local, remote: remote)
        let url = try #require(URL(string: "https://example.invalid"))
        await router.updateRemoteConfiguration(.init(
            enabled: true, baseURL: url, model: "remote", voice: "test", timeoutSeconds: 5
        ))
        let request = try await request(model: RemoteTTSConfiguration.descriptor(
            model: "remote", voice: "test", endpoint: url
        ))
        do {
            for try await _ in await router.synthesize(request) {}
            Issue.record("Expected transport failure")
        } catch is SynthesisError {
            #expect(await local.requestCount == 0)
        }
    }

    private func request(model: ModelDescriptor) async throws -> SpeechRequest {
        SpeechRequest(
            cleanedText: try await TextCleaner().ingest(.init(source: .clipboard, plainText: "Synthetic routing test.")),
            model: model, voice: nil, language: "en", source: .frontend
        )
    }
}

private actor RoutingLocalFixture: BackendSpeechSynthesizing {
    private(set) var requestCount = 0
    func synthesize(_ request: SpeechRequest) async -> AsyncThrowingStream<SynthesisEvent, Error> {
        requestCount += 1
        return AsyncThrowingStream { continuation in
            continuation.yield(.completed)
            continuation.finish()
        }
    }
    func cancelCurrentRequest() async {}
    func unloadModel() async {}
    func prepareDependencies(for model: ModelDescriptor) async throws {}
    func updateConfiguration(chunkTarget: Int, chunkDelay: Double, paragraphPause: Double, idleUnloadDelay: Double) async {}
    func generateVoiceSample(model: ModelDescriptor, text: String, language: String?, tuning: VoiceSynthesisTuning, seed: UInt64, reference: VoiceReference?) async throws -> GeneratedVoiceSample {
        throw CancellationError()
    }
}
