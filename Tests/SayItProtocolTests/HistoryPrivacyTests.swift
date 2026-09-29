import Foundation
import Testing
@testable import SayItProtocol

struct HistoryPrivacyTests {
    @Test("History is opt-in for new settings and settings saved by old versions")
    func defaultsToPrivate() throws {
        #expect(!BackendSettingsSnapshot().historyEnabled)
        #expect(try !JSONDecoder().decode(BackendSettingsSnapshot.self, from: Data("{}".utf8)).historyEnabled)
        let optedIn = BackendSettingsSnapshot(historyEnabled: true)
        let encoded = try JSONEncoder().encode(optedIn)
        #expect(try JSONDecoder().decode(BackendSettingsSnapshot.self, from: encoded).historyEnabled)
    }
}
