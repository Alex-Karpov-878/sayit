import AppKit
import SwiftUI

struct AppWindowCoordinator: View {
    @Environment(AppState.self) private var state
    @Environment(\.openWindow) private var openWindow

    @State private var handledInitialLaunch = false

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onAppear {
                guard !handledInitialLaunch else { return }
                handledInitialLaunch = true
                if AppLaunchPolicy.shouldPresentMainWindow(
                    onboardingComplete: state.settings.onboardingComplete,
                    isLoginLaunch: AppLaunchPolicy.isLoginLaunch
                ) {
                    presentMainWindow()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .sayItReopen)) { _ in
                if state.isShowingOnboarding {
                    openOnboardingIfNeeded(oldValue: false, newValue: true)
                } else {
                    presentMainWindow()
                }
            }
            .onChange(
                of: state.isShowingOnboarding,
                initial: true,
                openOnboardingIfNeeded
            )
    }

    private func presentMainWindow() {
        WindowActivator.prepareForWindowPresentation()
        openWindow(id: AppWindowID.main)
    }

    private func openOnboardingIfNeeded(
        oldValue: Bool,
        newValue: Bool
    ) {
        _ = oldValue
        guard newValue else { return }
        WindowActivator.prepareForWindowPresentation()
        openWindow(id: AppWindowID.onboarding)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension Notification.Name {
    static let sayItReopen = Notification.Name("sh.sayit.reopen")
}

@MainActor
enum AppLaunchPolicy {
    static var isLoginLaunch: Bool {
        NSAppleEventManager.shared().currentAppleEvent?
            .paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue
            == keyAELaunchedAsLogInItem
    }

    static func shouldPresentMainWindow(onboardingComplete: Bool, isLoginLaunch: Bool) -> Bool {
        onboardingComplete && !isLoginLaunch
    }
}
