import Testing
@testable import SayIt

@Suite("Main window launch policy")
@MainActor
struct AppLaunchPolicyTests {
    @Test("Only an ordinary launch after onboarding presents the main window")
    func launchPresentation() {
        #expect(AppLaunchPolicy.shouldPresentMainWindow(onboardingComplete: true, isLoginLaunch: false))
        #expect(!AppLaunchPolicy.shouldPresentMainWindow(onboardingComplete: false, isLoginLaunch: false))
        #expect(!AppLaunchPolicy.shouldPresentMainWindow(onboardingComplete: true, isLoginLaunch: true))
        #expect(!AppLaunchPolicy.shouldPresentMainWindow(onboardingComplete: false, isLoginLaunch: true))
    }
}
