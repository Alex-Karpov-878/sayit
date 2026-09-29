import Foundation
import Testing
@testable import SayItCore

@Suite("Security regressions")
struct SecurityRegressionTests {
    @Test("HTML resources are discarded without a rendering engine")
    func inertHTML() throws {
        let html = "<p>Hello &#x1F600; &amp; &#169;</p><img src='http://127.0.0.1:1/track'><link rel='stylesheet' href='file:///etc/passwd'><span title='x > y'>world</span>"
        let result = try TextParser().parse(.init(source: .clipboard, html: Data(html.utf8)))
        #expect(result.text == "Hello 😀 & ©\nworld")
        #expect(HTMLTextExtractor.text(from: "a<span title='>'>b</span>c") == "abc")
        #expect(HTMLTextExtractor.text(from: "&amp;lt;") == "&lt;")
    }

    @Test("Model paths cannot escape their destination", arguments: [
        "../secret", "/tmp/file", "a/../../b", "a//b", "a/./b", "a\\b", "a\0b", ""
    ])
    func rejectsPaths(_ path: String) {
        #expect(!ModelFilePolicy.isSafeRelativePath(path))
    }

    @Test("Model metadata requires a digest and a bounded file size")
    func modelFileValidation() {
        #expect(ModelFilePolicy.isSafeRelativePath("voices/af_heart.safetensors"))
        #expect(!ModelFilePolicy.isRepository("owner/../repo"))
        #expect(!ModelFilePolicy.isRepository("owner/repo?redirect=evil"))
        #expect(!ModelFilePolicy.isValid(.init(path: "config.json", byteCount: 5, sha256: nil)))
        #expect(!ModelFilePolicy.isValid(.init(path: "config.json", byteCount: 4_294_967_296,
                                              sha256: String(repeating: "a", count: 64))))
        #expect(ModelFilePolicy.isValid(.init(path: "config.json", byteCount: 5, sha256: nil,
                                             gitBlobSHA1: String(repeating: "b", count: 40))))
    }
}
