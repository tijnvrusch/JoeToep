// V22 — Het geluid-icoontje op een tab (balk én zijbalk) is een knop:
//   speelt de video in die tab → pauzeren;
//   staat hij stil (videopagina) → daar afspelen, en (instelbaar) meteen naar die tab wisselen.
// Omdat de andere tab dan gaat spelen, pauzeert de rest vanzelf ("één video tegelijk").
import SwiftUI

enum TabAudioIconPrefs {
    /// "playPause" (standaard), "switch" (alleen naar de tab gaan) of "off" (gewoon icoon).
    static var action: String { UserDefaults.standard.string(forKey: "tabIconActionV22") ?? "playPause" }
    static var switchOnPlay: Bool { UserDefaults.standard.object(forKey: "tabIconSwitchV22") as? Bool ?? true }
    static var hoverHint: Bool { UserDefaults.standard.object(forKey: "tabIconHintV22") as? Bool ?? true }
    static var fullscreenOnStart: Bool { UserDefaults.standard.object(forKey: "tabIconFullscreenV22") as? Bool ?? false }
}

@MainActor
enum TabAudioIcon {
    static func isActionable(_ tab: BrowserTab, _ session: WebSession) -> Bool {
        guard TabAudioIconPrefs.action != "off" else { return false }
        return session.isPlaying || session.isInPictureInPicture || NavigationPolicy.isPlaybackPage(tab.currentURL ?? session.restoredURL)
    }

    /// Wanneer het icoon het laatst gebruikt werd (zodat de tab-klik eronder niet óók reageert).
    static var lastAction = Date.distantPast
    /// true terwijl het icoon zelf de tab kiest (die keuze mag niet worden tegengehouden).
    static var selecting = false
    private static func choose(_ select: () -> Void) { selecting = true; select(); selecting = false }

    static func perform(_ tab: BrowserTab, _ session: WebSession, select: () -> Void) {
        lastAction = Date()
        if TabAudioIconPrefs.action == "switch" { choose(select); return }
        // V22.2: native PiP speelt in een eigen AVPlayer terwijl de webvideo gepauzeerd is;
        // remoteToggle() zou die webvideo juist starten → PiP sluiten en pauzeren.
        if session.nativePiPActive || session.isNativePiPStarting {
            session.stopPiPAndPause()
            return
        }
        if session.isPlaying || session.isInPictureInPicture {
            session.remoteToggle()                       // pauzeren
            return
        }
        if TabAudioIconPrefs.switchOnPlay { choose(select) }
        session.releaseQuiet()
        if session.hasLoadedContent {
            if !TabAudioIconPrefs.fullscreenOnStart {
                // Starten via het icoon = gewoon verder spelen, niet ineens fullscreen.
                session.webView.evaluateJavaScript("window.__jtSkipFSUntil=Date.now()+2000;0", completionHandler: nil)
            }
            session.remoteToggleIfPaused()
            if TabAudioIconPrefs.fullscreenOnStart {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    session.webView.evaluateJavaScript("window.JoeToepMedia?.restoreFullscreen(true)", completionHandler: nil)
                }
            }
        } else {
            // Nog niet geladen (tab van een ander apparaat / na herstart): laden en meteen spelen.
            session.forcePlayOnStart = true
            session.suppressAutoFullscreenOnce = !TabAudioIconPrefs.fullscreenOnStart
            session.syncedStartPaused = false
        }
    }

    static func symbol(_ tab: BrowserTab, _ session: WebSession, hovering: Bool, base: String) -> String {
        guard isActionable(tab, session), TabAudioIconPrefs.action == "playPause" else { return base }
        if hovering && TabAudioIconPrefs.hoverHint {
            return session.isPlaying ? "pause.fill" : "play.fill"
        }
        return base
    }
}

/// Instellingen voor het tab-icoontje (pagina "Tabs, sidebar & search bar").
struct TabAudioIconSettings: View {
    @AppStorage("tabIconActionV22") private var action = "playPause"
    @AppStorage("tabIconSwitchV22") private var switchOnPlay = true
    @AppStorage("tabIconHintV22") private var hint = true
    @AppStorage("tabIconFullscreenV22") private var fullscreen = false
    @AppStorage("advancedModeV22") private var advanced = false
    var body: some View {
        Section {
            Picker("Clicking the sound icon on a tab", selection: $action) {
                Text("Play / pause that tab").tag("playPause")
                Text("Only switch to that tab").tag("switch")
                Text("Nothing").tag("off")
            }
            if action == "playPause" {
                Toggle("Switch to the tab when it starts playing", isOn: $switchOnPlay)
                if advanced {
                    Toggle("Show play/pause on hover", isOn: $hint)
                    Toggle("Go fullscreen when started from the icon", isOn: $fullscreen)
                }
            }
        } header: { Text("Tab sound icon") } footer: {
            Text("Playing tab: the icon pauses it. Another video tab: the icon starts it there (other tabs pause automatically). Works in the tab bar and the sidebar on Mac, iPhone and iPad.")
        }
    }
}
