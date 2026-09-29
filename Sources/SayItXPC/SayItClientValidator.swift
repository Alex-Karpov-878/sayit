import Foundation
import Security
import SayItProtocol

/// Authenticate the exact executables shipped together, including ad-hoc builds.
/// Identifiers alone are not identities: another local executable can copy them.
public enum SayItCodeSigningRequirement {
    private static let denyAll = "cdhash H\"0000000000000000000000000000000000000000\""

    public static func forBundleIdentifiers(
        _ bundleIdentifiers: Set<String>
    ) -> String {
        guard let app = enclosingApplication(), !bundleIdentifiers.isEmpty else {
            return denyAll
        }
        let paths = [
            SayItServiceIdentifiers.applicationBundle: "Contents/MacOS/SayIt",
            SayItServiceIdentifiers.agentBundle:
                "Contents/Library/LaunchServices/SayItAgent.app/Contents/MacOS/SayItAgent",
            SayItServiceIdentifiers.selectionAgentBundle: "Contents/Helpers/SayItSelectionAgent",
            SayItServiceIdentifiers.commandLineBundle:
                "Contents/Helpers/SayItCLI.app/Contents/MacOS/sayit"
        ]
        var requirements: [String] = []
        for identifier in bundleIdentifiers.sorted() {
            guard let path = paths[identifier],
                  let requirement = requirement(for: app.appending(path: path)) else {
                return denyAll
            }
            requirements.append(requirement)
        }
        return requirements.map { "(\($0))" }.joined(separator: " or ")
    }

    static func requirement(for executable: URL) -> String? {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(executable as CFURL, [], &code) == errSecSuccess,
              let code,
              SecStaticCodeCheckValidity(code, [], nil) == errSecSuccess else { return nil }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation),
                                            &information) == errSecSuccess,
              let values = information as? [String: Any],
              let hash = values[kSecCodeInfoUnique as String] as? Data,
              hash.count == 20 else { return nil }
        let hex = hash.map { String(format: "%02x", $0) }.joined()
        return "cdhash H\"\(hex)\""
    }

    private static func enclosingApplication() -> URL? {
        // Resolve the CLI symlink, then walk past its nested helper bundle.
        guard var location = Bundle.main.executableURL?.resolvingSymlinksInPath() else { return nil }
        while location.path != "/" {
            if location.pathExtension == "app",
               FileManager.default.fileExists(atPath:
                    location.appending(path: "Contents/MacOS/SayIt").path) {
                return location
            }
            location.deleteLastPathComponent()
        }
        return nil
    }
}

public struct SayItClientValidator {
    private let trustedBundleIdentifiers: Set<String>

    public var codeSigningRequirement: String {
        SayItCodeSigningRequirement.forBundleIdentifiers(
            trustedBundleIdentifiers
        )
    }

    public init(
        trustedBundleIdentifiers: Set<String> = Set(
            SayItServiceIdentifiers.trustedClientBundleIdentifiers
        )
    ) {
        self.trustedBundleIdentifiers = trustedBundleIdentifiers
    }

    public func accepts(_ connection: NSXPCConnection) -> Bool {
        connection.effectiveUserIdentifier == geteuid()
    }
}
