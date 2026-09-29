import Foundation
import Security
import Testing
@testable import SayItXPC

@Suite("XPC peer identity")
struct CodeSigningRequirementTests {
    @Test("Ad-hoc executables with the same signing identifier are not interchangeable")
    func rejectsCopiedIdentifier() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let trusted = root.appending(path: "trusted")
        let impostor = root.appending(path: "impostor")
        for (source, destination) in [("/usr/bin/true", trusted), ("/usr/bin/false", impostor)] {
            try FileManager.default.copyItem(at: URL(filePath: source), to: destination)
            let signer = Process()
            signer.executableURL = URL(filePath: "/usr/bin/codesign")
            signer.arguments = ["--force", "--sign", "-", "--options", "runtime",
                                "--identifier", "sh.sayit.test.same-identifier", destination.path]
            signer.standardOutput = FileHandle.nullDevice
            signer.standardError = FileHandle.nullDevice
            try signer.run()
            signer.waitUntilExit()
            #expect(signer.terminationStatus == 0)
        }
        let requirement = try #require(SayItCodeSigningRequirement.requirement(for: trusted))
        var compiled: SecRequirement?
        #expect(SecRequirementCreateWithString(requirement as CFString, [], &compiled) == errSecSuccess)
        for (url, accepted) in [(trusted, true), (impostor, false)] {
            var code: SecStaticCode?
            #expect(SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess)
            let validCode = try #require(code)
            #expect((SecStaticCodeCheckValidity(validCode, [], compiled) == errSecSuccess) == accepted)
        }
    }

    @Test("Missing bundles fail closed, including debug builds")
    func missingBundle() throws {
        let requirement = SayItCodeSigningRequirement.forBundleIdentifiers(["untrusted.identifier"])
        var compiled: SecRequirement?
        #expect(SecRequirementCreateWithString(requirement as CFString, [], &compiled) == errSecSuccess)
        var code: SecStaticCode?
        #expect(SecStaticCodeCreateWithPath(URL(filePath: "/usr/bin/true") as CFURL, [], &code) == errSecSuccess)
        let validCode = try #require(code)
        #expect(SecStaticCodeCheckValidity(validCode, [], compiled) != errSecSuccess)
    }

    @Test("An exact executable requirement accepts its source and rejects another executable")
    func bindsExecutable() throws {
        let requirement = try #require(SayItCodeSigningRequirement.requirement(for: URL(filePath: "/usr/bin/true")))
        var compiled: SecRequirement?
        #expect(SecRequirementCreateWithString(requirement as CFString, [], &compiled) == errSecSuccess)
        for (path, accepted) in [("/usr/bin/true", true), ("/usr/bin/false", false)] {
            var code: SecStaticCode?
            #expect(SecStaticCodeCreateWithPath(URL(filePath: path) as CFURL, [], &code) == errSecSuccess)
            let validCode = try #require(code)
            #expect((SecStaticCodeCheckValidity(validCode, [], compiled) == errSecSuccess) == accepted)
        }
    }
}
