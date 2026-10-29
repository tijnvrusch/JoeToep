// Dit bestand tekent één enkel tabblad met daarin de video-player (webpagina)
// en de bedieningsbalk eromheen, en luistert naar allerlei systeemgebeurtenissen
// (app naar achtergrond, scherm vergrendeld, enz.) om de speler correct te laten reageren.
import SwiftUI
// Op iPhone/iPad gebruiken we UIKit-notificaties (bijv. voor scènes/schermrotatie);
// op de Mac gebruiken we in plaats daarvan AppKit-notificaties.
#if os(iOS)
import UIKit
#else
import AppKit
#endif

// Eén "kaart" in de tab-workspace: de webweergave plus bedieningsbalk voor één tabblad.
struct TabPlayerView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var session: WebSession
    // "let" (in plaats van "var") betekent dat deze waarde niet meer verandert
    // nadat de view is aangemaakt: geeft aan of dít tabblad het actieve is.
    let selected: Bool
    // Een optionele waarde (kan nil zijn) met standaardwaarde nil: extra acties
    // die alleen op macOS vanuit het menu worden doorgegeven.
    var actions: WorkspaceActions? = nil
    @State private var showingSettings = false
    @ObservedObject private var chrome = ChromeAutoHide.shared
    @AppStorage("autoHideRevealEdgeV20") private var autoHideRevealEdge = true
    @AppStorage("oneBarLayoutV21") private var oneBarSetting = true
    @AppStorage("sidebarTabsV21") private var sidebarSetting = false
    @Environment(\.joeToepTheme) private var theme
    // Leest de systeeminstelling "Beweging verminderen" (toegankelijkheid).
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // GeometryReader geeft je de beschikbare breedte/hoogte van de ruimte
        // waarin deze view getekend wordt, zodat je daarop kan inspelen.
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Op de Mac staat de bedieningsbalk bovenaan (behalve tijdens
                // een echte video-fullscreen/"video stage").
                #if os(macOS)
                if !session.isVideoStage && !chrome.buttonsHidden && !LayoutPrefs.buttonsElsewhere(oneBar: oneBarSetting, sidebar: sidebarSetting) {
                PlayerControlBar(session: session, settings: settings, availableWidth: geometry.size.width, actions: actions) {
                    showingSettings = true
                }
                .frame(minWidth: 0, maxWidth: geometry.size.width, alignment: .center).clipped()
                .onHover { chrome.setHovering($0) }
                .transition(.move(edge: .top).combined(with: .opacity))
                }
                #endif
                // ZStack stapelt views bovenop elkaar (in plaats van naast of
                // onder elkaar); de laatst genoemde ligt bovenop.
                ZStack {
                    // De eigenlijke webpagina/video, getoond via een systeem-webview.
                    WebContentView(webView: session.webView)
                        .accessibilityIdentifier("player.webView")
                    if session.isTestMode {
                        // UI-test probe: real presentation state (fullscreen / PiP / playing).
                        // Bijna onzichtbare tekst (opacity 0.02) die alleen door
                        // geautomatiseerde tests wordt uitgelezen, niet door mensen.
                        Text("fs=\(session.isFullscreen ? 1 : 0) pip=\(session.isInPictureInPicture ? 1 : 0) play=\(session.isPlaying ? 1 : 0)")
                            .font(.system(size: 8)).opacity(0.02).allowsHitTesting(false)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .accessibilityIdentifier("debug.state")
                        Text(session.lifecycleTail.isEmpty ? "-" : session.lifecycleTail)
                            .font(.system(size: 4)).opacity(0.02).allowsHitTesting(false).lineLimit(1)
                            .frame(maxWidth: 40, maxHeight: .infinity, alignment: .bottomLeading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("debug.lifecycle")
                    }
                    // V19.2: nieuwe-tab-pagina (meteen typen, platform kiezen, snelkoppelingen).
                    if session.showsNewTabPage && !session.isTestMode {
                        NewTabPage(session: session, settings: settings)
                            .transition(.opacity)
                    }
                    // Als de video losgekoppeld in een zwevend mini-venster
                    // (Picture-in-Picture) afspeelt, tonen we hier een melding
                    // in plaats van de gewone webpagina.
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
                .frame(width: geometry.size.width)
                .frame(maxHeight: .infinity)
                // .clipped() knipt alles wat buiten deze view valt weg, zodat
                // er niks buiten de grenzen zichtbaar blijft.
                .clipped()
                // Op iPhone/iPad staat de bedieningsbalk juist ONDERaan.
                #if os(iOS)
                if !session.isVideoStage && !chrome.buttonsHidden && !LayoutPrefs.buttonsElsewhere(oneBar: oneBarSetting, sidebar: sidebarSetting) {
                PlayerControlBar(session: session, settings: settings, availableWidth: geometry.size.width, actions: actions) {
                    showingSettings = true
                }
                // V22: nooit breder dan het scherm (anders schoof de hele pagina naar links).
                .frame(minWidth: 0, maxWidth: geometry.size.width, alignment: .center).clipped()
                .simultaneousGesture(TapGesture().onEnded { chrome.reveal() })
                .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                #endif
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            #if os(iOS)
            .overlay(alignment: .bottom) {
                if chrome.buttonsHidden && autoHideRevealEdge && !session.isVideoStage { AutoHideRevealZone(height: 18) }
            }
            #else
            .overlay(alignment: .top) {
                if chrome.buttonsHidden && chrome.parts == .buttons && autoHideRevealEdge && !session.isVideoStage { AutoHideRevealZone(height: 8) }
            }
            #endif
            // .overlay(alignment: .top) legt extra inhoud bovenop, hier
            // uitgelijnd aan de bovenkant: een tijdelijke meldingsbanner.
            .overlay(alignment: .top) {
                // "if let" pakt de waarde uit een optional (session.notice)
                // en gaat alleen het blok in als die niet nil is.
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
                        // .task(id:) start een achtergrondtaak die opnieuw
                        // begint zodra de meegegeven id (notice.id) verandert;
                        // hier: verberg de banner automatisch na 5 seconden.
                        .task(id: notice.id) {
                            try? await Task.sleep(for: .seconds(5))
                            guard !Task.isCancelled, session.notice?.id == notice.id else { return }
                            session.dismissNotice()
                        }
                }
            }
        }
        .background(theme.background.ignoresSafeArea())
        // .task draait automatisch zodra deze view voor het eerst verschijnt.
        .task {
            // Alleen het geselecteerde (actieve) tabblad laden we meteen de webpagina.
            if selected { session.start(with: settings.snapshot) }
            #if os(iOS)
            session.webView.accessibilityElementsHidden = !selected
            #endif
        }
        // .onChange(of:) draait telkens als de waarde van "selected" wijzigt
        // (dus als je van tabblad wisselt).
        .onChange(of: selected) { _, visible in
            if visible { session.start(with: settings.snapshot) }
            #if os(iOS)
            // Background tabs keep their page but are not exposed to VoiceOver.
            session.webView.accessibilityElementsHidden = !visible
            #endif
        }
        // Als de gebruiker instellingen wijzigt, passen we die direct toe op de sessie.
        .onChange(of: settings.snapshot) { _, updated in session.apply(updated) }
        // .sheet toont een apart schermpje (modaal) bovenop dit scherm. Hier
        // combineren we twee mogelijke redenen (instellingen of inlogscherm)
        // in één handgemaakte Binding met eigen get/set-logica.
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
                SettingsView(settings: settings, session: session, onClose: { showingSettings = false })
                    .environment(\.joeToepTheme, theme)
                    #if os(macOS)
                    // V20: klik buiten het instellingenvenster = sluiten.
                    .background(ClickOutsideCloser { showingSettings = false })
                    #endif
                    .joeToepTextScale(theme.textScale)   // V16.2.1: settings follow the text size
                    .preferredColorScheme(theme.style.colorScheme)
                    .tint(theme.accent)
                    #if os(macOS)
                    .frame(minWidth: 560, idealWidth: 680, maxWidth: 900, minHeight: 640, idealHeight: 780, maxHeight: 1100)
                    #endif
            }
        }
        // .onReceive luistert naar berichten via NotificationCenter (Apple's
        // systeem om gebeurtenissen door de hele app te versturen). Hier:
        // reageer op het bericht "open instellingen" als dit tabblad actief is.
        .onReceive(NotificationCenter.default.publisher(for: .joeToepOpenSettings)) { note in
            if selected, (note.object as AnyObject?) === session { showingSettings = true; chrome.reveal() }
        }
        // De volgende blokken luisteren naar systeemgebeurtenissen: app naar
        // de achtergrond/voorgrond, scherm vergrendeld/ontgrendeld, gedraaid,
        // enzovoort, en geven dat door aan de sessie zodat de video netjes
        // pauzeert/hervat.
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
        // Zet het ontvangen van schermrotatie-gebeurtenissen aan zodra deze view verschijnt.
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

#if os(macOS)
/// V20 — Sluit een sheet zodra je buiten het sheet-venster klikt (in het venster eronder).
struct ClickOutsideCloser: NSViewRepresentable {
    let onClose: () -> Void
    func makeNSView(context: Context) -> NSView { Tracker(onClose: onClose) }
    func updateNSView(_ view: NSView, context: Context) { (view as? Tracker)?.onClose = onClose }
    final class Tracker: NSView {
        var onClose: () -> Void
        private var monitor: Any?
        init(onClose: @escaping () -> Void) { self.onClose = onClose; super.init(frame: .zero) }
        required init?(coder: NSCoder) { return nil }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
                guard let self, let sheet = self.window else { return event }
                if let clicked = event.window, clicked !== sheet, clicked.attachedSheet === sheet || sheet.sheetParent === clicked {
                    DispatchQueue.main.async { self.onClose() }
                    return nil
                }
                return event
            }
        }
        deinit { if let monitor { NSEvent.removeMonitor(monitor) } }
    }
}
#endif

