import Foundation
import SayItCore
import Testing
@testable import SayItBackend

@Suite("Remote TTS transport", .serialized)
struct RemoteTTSTransportTests {
    @Test("Loopback speech preserves list silence and source timing")
    func listTiming() async throws {
        let server = try LoopbackSpeechServer()
        defer { server.stop() }
        let synthesizer = OpenAICompatibleSpeechSynthesizer(apiKeyProvider: { _ in nil })
        await synthesizer.updateRemoteConfiguration(server.configuration())
        await synthesizer.updateConfiguration(
            chunkTarget: 650, chunkDelay: 0, paragraphPause: 0, idleUnloadDelay: 0
        )
        let cleaned = try await TextCleaner().ingest(.init(
            source: .clipboard, plainText: "- Milk\n- Bread"
        ))
        let request = SpeechRequest(
            cleanedText: cleaned,
            model: RemoteTTSConfiguration.descriptor(model: "fixture", voice: "test", endpoint: server.url),
            voice: "test", language: "en", source: .frontend
        )
        var audio: [AudioChunk] = []
        for try await event in await synthesizer.synthesize(request) {
            if case .audio(let chunk) = event { audio.append(chunk) }
        }
        #expect(audio.count == 2)
        #expect(audio.first?.samples.count == 2400)
        let second = try #require(audio.last)
        #expect(second.samples.count == 8400)
        #expect(second.speechStartOffset == 0.25)
        #expect(second.samples.prefix(6000).allSatisfy { $0 == 0 })
        #expect(second.samples.dropFirst(6000).contains { $0 != 0 })
    }

    @Test("Refuses redirects and oversized or malformed responses", arguments: ["redirect", "oversized", "malformed", "unauthorized", "nonfinite"])
    func rejectsBadResponses(mode: String) async throws {
        let server = try LoopbackSpeechServer()
        defer { server.stop() }
        let synthesizer = OpenAICompatibleSpeechSynthesizer(apiKeyProvider: { _ in "synthetic-secret" })
        await synthesizer.updateRemoteConfiguration(server.configuration(mode: mode))
        let request = try await makeRequest(server)
        do {
            for try await _ in await synthesizer.synthesize(request) {}
            Issue.record("Expected rejection for \(mode)")
        } catch {
            #expect(!error.localizedDescription.contains("synthetic-secret"))
            #expect(!error.localizedDescription.contains("private text"))
            if mode == "redirect" {
                guard case SynthesisError.remoteTTSHTTPStatus(let status, _) = error else {
                    Issue.record("Expected redirect refusal, got \(error)")
                    return
                }
                #expect(status == 307)
            }
        }
    }

    @Test("Cancellation interrupts a waiting transport without completed audio")
    func cancellation() async throws {
        let server = try LoopbackSpeechServer()
        defer { server.stop() }
        let synthesizer = OpenAICompatibleSpeechSynthesizer(apiKeyProvider: { _ in nil })
        await synthesizer.updateRemoteConfiguration(server.configuration(mode: "slow"))
        let stream = await synthesizer.synthesize(try await makeRequest(server))
        let consumer = Task {
            do {
                for try await event in stream {
                    if case .audio = event { Issue.record("Canceled request produced audio") }
                    if case .completed = event { Issue.record("Canceled request completed") }
                }
            } catch is CancellationError {
                // Expected.
            }
        }
        try await Task.sleep(for: .milliseconds(150))
        await synthesizer.cancelCurrentRequest()
        try await consumer.value
    }

    @Test("Transport timeout bounds an unresponsive server")
    func timeout() async throws {
        let server = try LoopbackSpeechServer()
        defer { server.stop() }
        let synthesizer = OpenAICompatibleSpeechSynthesizer(apiKeyProvider: { _ in nil })
        await synthesizer.updateRemoteConfiguration(server.configuration(mode: "slow"))
        let started = ContinuousClock.now
        do {
            for try await _ in await synthesizer.synthesize(try await makeRequest(server)) {}
            Issue.record("Expected timeout")
        } catch {
            #expect(ContinuousClock.now - started < .seconds(15))
        }
    }

    private func makeRequest(_ server: LoopbackSpeechServer) async throws -> SpeechRequest {
        SpeechRequest(
            cleanedText: try await TextCleaner().ingest(.init(source: .clipboard, plainText: "Synthetic transport test.")),
            model: RemoteTTSConfiguration.descriptor(model: "fixture", voice: "test", endpoint: server.url),
            voice: "test", language: "en", source: .frontend
        )
    }
}

private final class LoopbackSpeechServer {
    let process = Process()
    let url: URL

    init() throws {
        let output = Pipe()
        process.executableURL = URL(filePath: "/usr/bin/python3")
        process.arguments = ["-u", "-c", #"""
import http.server, io, json, struct, time, wave
class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args): pass
    def do_POST(self):
        payload = self.rfile.read(int(self.headers.get('Content-Length', '0')))
        if '/slow/' in self.path: time.sleep(30)
        if '/redirect/' in self.path:
            self.send_response(307)
            self.send_header('Location', '/v1/audio/speech')
            self.end_headers()
            return
        if '/oversized/' in self.path:
            self.send_response(200)
            self.send_header('Content-Length', str(33*1024*1024))
            self.end_headers()
            return
        if '/unauthorized/' in self.path:
            self.send_response(401)
            self.end_headers()
            self.wfile.write(b'synthetic-secret private text')
            return
        data = b'not audio'
        if '/malformed/' not in self.path:
            stream = io.BytesIO()
            with wave.open(stream, 'wb') as audio:
                audio.setnchannels(1); audio.setsampwidth(2); audio.setframerate(24000)
                audio.writeframes(struct.pack('<h', 1000) * 2400)
            data = stream.getvalue()
        if '/nonfinite/' in self.path:
            samples = struct.pack('<f', float('nan')) * 2400
            fmt = struct.pack('<HHIIHH', 3, 1, 24000, 96000, 4, 32)
            body = b'WAVEfmt ' + struct.pack('<I', len(fmt)) + fmt + b'data' + struct.pack('<I', len(samples)) + samples
            data = b'RIFF' + struct.pack('<I', len(body)) + body
        self.send_response(200)
        self.send_header('Content-Type', 'audio/wav')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)
server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
print(server.server_port, flush=True)
server.serve_forever()
"""#]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        var line = Data()
        while let byte = try output.fileHandleForReading.read(upToCount: 1), !byte.isEmpty {
            if byte == Data([10]) { break }
            line.append(byte)
        }
        guard let port = String(data: line, encoding: .utf8),
              let parsed = URL(string: "http://127.0.0.1:\(port)") else {
            process.terminate()
            throw CocoaError(.fileReadCorruptFile)
        }
        url = parsed
    }

    func configuration(mode: String = "normal") -> RemoteTTSConfiguration {
        RemoteTTSConfiguration(
            enabled: true, baseURL: url.appending(path: mode),
            model: "fixture", voice: "test", timeoutSeconds: 5
        )
    }

    func stop() {
        if process.isRunning { process.terminate() }
        process.waitUntilExit()
    }
}
