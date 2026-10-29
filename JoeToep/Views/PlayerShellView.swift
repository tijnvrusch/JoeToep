import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct TabPlayerView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var session: WebSession
    let selected: Bool
    var actions: WorkspaceActions? = nil
    @State private var showingSettings = false
    @Environment(\.joeToepTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                #if os(macOS)
                if !session.isVideoStage {
                PlayerControlBar(session: session, settings: settings, availableWidth: geometry.size.width, actions: actions) {
                    showingSettings = true
                }
                }
                #endif
                ZStack {
                    WebContentView(webView: session.webView)
                        .accessibilityIdentifier("player.webView")
                    if session.isTestMode {
                        // UI-test probe: real presentation state (fullscreen / PiP / playing).
                        Text("fs=\(session.isFullscreen ? 1 : 0) pip=\(session.isInPictureInPicture ? 1 : 0) play=\(session.isPlaying ? 1 : 0)")
                            .font(.system(size: 8)).opacity(0.02).allowsHitTesting(false)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .accessibilityIdentifier("debug.state")
                    }
                    if session.isFloating {
                        VStack(spacing: 12) {
                            Image(systemName: "pip.fill").font(.largeTitle)
                            Text("Playing in the floating mini-player").font(.headline)
                            Button("Return to this window", action: session.togglePictureInPicture)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(white: 0.04))
                    }
                }
                .padding(settings.edgeToEdge ? 0 : 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                #if os(iOS)
                if !session.isVideoStage {
                PlayerControlBar(session: session, settings: settings, availableWidth: geometry.size.width, actions: actions) {
                    showingSettings = true
                }
                }
                #endif
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .overlay(alignment: .top) {
                if let notice = session.notice {
                    NoticeBanner(notice: notice, dismiss: session.dismissNotice)
                        .padding(.horizontal, 10)
                        #if os(macOS)
                        .padding(.top, settings.toolbarDensity.height + 8)
                        #else
                        .padding(.top, 8)
                        #endif
                        .frame(maxWidth: min(520, geometry.size.width))
                        .accessibilityIdentifier("notice.banner")
                        .task(id: notice.id) {
                            try? await Task.sleep(for: .seconds(5))
                            guard !Task.isCancelled, session.notice?.id == notice.id else { return }
                            session.dismissNotice()
                        }
                }
            }
        }
        .background(theme.background.ignoresSafeArea())
        .task {
            if selected { session.start(with: settings.snapshot) }
            #if os(iOS)
            session.webView.accessibilityElementsHidden = !selected
            #endif
        }
        .onChange(of: selected) { _, visible in
            if visible { session.start(with: settings.snapshot) }
            #if os(iOS)
            // Background tabs keep their page but are not exposed to VoiceOver.
            session.webView.accessibilityElementsHidden = !visible
            #endif
        }
        .onChange(of: settings.snapshot) { _, updated in session.apply(updated) }
        .sheet(isPresented: Binding(
            get: { showingSettings || session.authenticationWebView != nil },
            set: { if !$0 { showingSettings = false; session.authenticationWebView = nil } }
        )) {
            if let login = session.authenticationWebView {
                NavigationStack {
                    WebContentView(webView: login)
                        .toolbar { ToolbarItem(placement: .cancellationAction) {
                            Button("Close sign-in") { session.authenticationWebView = nil }
                        } }
                }
                #if os(macOS)
                .frame(minWidth: 500, minHeight: 650)
                #endif
            } else {
                SettingsView(settings: settings, session: session)
                    .environment(\.joeToepTheme, theme)
                    .preferredColorScheme(theme.style.colorScheme)
                    .tint(theme.accent)
                    #if os(macOS)
                    .frame(minWidth: 560, idealWidth: 680, maxWidth: 900, minHeight: 640, idealHeight: 780, maxHeight: 1100)
                    #endif
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .joeToepOpenSettings)) { note in
            if selected, (note.object as AnyObject?) === session { showingSettings = true }
        }
        #if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: UIScene.willDeactivateNotification)) { note in
            if let scene = note.object as? UIScene, scene === session.webView.window?.windowScene,
               selected || session.isInPictureInPicture { session.applicationWillDeactivate() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            if selected || session.isInPictureInPicture { session.applicationDidActivate() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            if selected || session.isInPictureInPicture { session.applicationWillEnterForeground() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            if selected || session.isInPictureInPicture { session.applicationDidEnterBackground() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataWillBecomeUnavailableNotification)) { _ in
            if selected || session.isInPictureInPicture { session.platformTransition("lock") }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
            if selected || session.isInPictureInPicture { session.platformTransition("unlock") }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            if selected { session.deviceOrientationChanged() }
        }
        .onAppear { UIDevice.current.beginGeneratingDeviceOrientationNotifications() }
        #else
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            if selected || session.isInPictureInPicture { session.applicationWillDeactivate() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            if selected || session.isInPictureInPicture { session.applicationDidActivate() }
        }
        #endif
    }
}
