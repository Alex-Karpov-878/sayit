import AppKit
import XCTest

final class SayItUITests: XCTestCase {
    @MainActor
    func testMinimumWindowSizeAndSettingsMenu() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-onboardingComplete", "YES",
            "-backgroundServiceUserDisabled", "YES"
        ]
        app.launch()
        defer { app.terminate() }
        let window = app.windows["Say It"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        let corner = window.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1))
            .withOffset(CGVector(dx: -2, dy: -2))
        corner.press(forDuration: 0.1, thenDragTo:
            window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
        XCTAssertGreaterThanOrEqual(window.frame.width, 860)
        XCTAssertGreaterThanOrEqual(window.frame.height, 560)
        XCTAssertLessThanOrEqual(window.frame.width, 960)
        app.menuBars.menuBarItems["SayIt"].click()
        app.menuItems["Settings…"].click()
        XCTAssertEqual(app.windows.matching(identifier: "Say It").count, 1)
    }

    @MainActor
    func testLoginEventKeepsMainWindowHidden() async throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-onboardingComplete", "YES",
            "-backgroundServiceUserDisabled", "YES"
        ]
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.windows["Say It"].waitForExistence(timeout: 10))
        let url = try XCTUnwrap(NSWorkspace.shared.frontmostApplication?.bundleURL)
        app.terminate()

        let event = NSAppleEventDescriptor(
            eventClass: AEEventClass(kCoreEventClass),
            eventID: AEEventID(kAEOpenApplication),
            targetDescriptor: nil,
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
        event.setParam(NSAppleEventDescriptor(enumCode: OSType(keyAELaunchedAsLogInItem)),
                       forKeyword: AEKeyword(keyAEPropData))
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.arguments = app.launchArguments
        configuration.appleEvent = event
        let running = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        try await Task.sleep(for: .seconds(2))
        XCTAssertFalse(running.isTerminated)
        XCTAssertFalse(app.windows["Say It"].exists)
        XCTAssertFalse(app.windows["Welcome to Say It"].exists)
    }

    @MainActor
    func testLaunchOpensMainWindow() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-onboardingComplete", "YES",
            "-backgroundServiceUserDisabled", "YES"
        ]
        defer { app.terminate() }
        app.launch()

        XCTAssertTrue(app.windows["Say It"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["Voices"].firstMatch.exists)
    }

    @MainActor
    func testReopeningRestoresMainWindowWithoutRestarting() async throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "-onboardingComplete", "YES",
            "-backgroundServiceUserDisabled", "YES"
        ]
        defer { app.terminate() }
        app.launch()

        let window = app.windows["Say It"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        app.descendants(matching: .any)["Voices"].firstMatch.click()
        XCTAssertTrue(app.popUpButtons["voice-model-picker"].waitForExistence(timeout: 5))

        XCTAssertEqual(app.state, .runningForeground)
        let running = try XCTUnwrap(NSWorkspace.shared.frontmostApplication)
        let url = try XCTUnwrap(running.bundleURL)
        window.buttons[XCUIIdentifierCloseWindow].click()
        XCTAssertTrue(window.waitForNonExistence(timeout: 5))
        XCTAssertFalse(running.isTerminated, "Closing the window must keep hotkeys available")

        // Launch Services sends the same reopen event as Spotlight or Finder.
        let reopened = try await NSWorkspace.shared.openApplication(
            at: url, configuration: NSWorkspace.OpenConfiguration()
        )
        XCTAssertEqual(reopened.processIdentifier, running.processIdentifier)
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        XCTAssertTrue(app.popUpButtons["voice-model-picker"].exists, "Keep the selected settings pane")

        _ = try await NSWorkspace.shared.openApplication(
            at: url, configuration: NSWorkspace.OpenConfiguration()
        )
        app.typeKey(",", modifierFlags: .command)
        XCTAssertEqual(app.windows.matching(identifier: "Say It").count, 1)
    }

    @MainActor
    func testOnboardingContinuesInIndependentWindow() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "-onboardingComplete", "NO",
            "-backgroundServiceUserDisabled", "YES"
        ]
        defer { app.terminate() }
        app.launch()

        let privacyTitle = app.staticTexts["Private by design"]
        XCTAssertTrue(privacyTitle.waitForExistence(timeout: 10))

        app.buttons["Continue"].click()

        XCTAssertTrue(
            app.staticTexts["Choose a voice"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.windows["Welcome to Say It"].exists)
    }
}
