import SwiftUI

struct RootView: View {
    @StateObject private var settings: AppSettings
    private static var resetTestDefaults = false
    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            let suite = "nl.tijn.joetoep.ui-tests"
            let defaults = UserDefaults(suiteName: suite) ?? .standard
            if !Self.resetTestDefaults {
                defaults.removePersistentDomain(forName: suite)
                if !ProcessInfo.processInfo.arguments.contains("--restore-tabs") {
                    UserDefaults(suiteName: "nl.tijn.joetoep.ui-tabs")?.removePersistentDomain(forName: "nl.tijn.joetoep.ui-tabs")
                }
                Self.resetTestDefaults = true
            }
            let model = AppSettings(defaults: defaults)
            if ProcessInfo.processInfo.arguments.contains("--skip-onboarding") { model.acceptServiceNotice() }
            if ProcessInfo.processInfo.arguments.contains("--tab-close-always") { model.tabCloseButtons = .always }
            _settings = StateObject(wrappedValue: model)
        } else { _settings = StateObject(wrappedValue: AppSettings()) }
        #else
        _settings = StateObject(wrappedValue: AppSettings())
        #endif
    }
    var body: some View {
        Group {
            if settings.acceptedServiceNotice { PlayerShellView(settings: settings) }
            else { OnboardingView(settings: settings) }
        }.task { AppIconController.shared.restore() }
    }
}
