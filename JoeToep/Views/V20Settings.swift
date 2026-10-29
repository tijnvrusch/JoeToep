// V20 — Instellingenpagina's: Muziek & Spotify, en de bovenbalk automatisch verbergen.
import SwiftUI
#if os(iOS)
import UIKit
#endif

struct MusicSettings: View {
    @ObservedObject private var spotify = SpotifyController.shared
    @ObservedObject private var coordinator = SpotifyCoordinator.shared
    @AppStorage("showMediaHubV20") private var showMediaHub = true
    @AppStorage("mediaHubShowPausedV20") private var showPaused = true

    var body: some View {
        Form {
            Section {
                SpotifyWidget().listRowInsets(EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6))
            } header: { Text("Spotify") } footer: {
                #if os(macOS)
                Text("JoeToep controls the Spotify app on this Mac. The first time, macOS asks whether JoeToep may control Spotify — choose OK. Your iPhone and iPad can control it too while they are connected (Sync & devices).")
                #else
                Text("Shows and controls Spotify on your Mac while it is connected (Sync & devices). Without a Mac, JoeToep opens the Spotify app.")
                #endif
            }
            Section("When a video starts playing") {
                Picker("Spotify", selection: $coordinator.behaviourRaw) {
                    ForEach(SpotifyCoordinator.VideoBehaviour.allCases) { Text($0.title).tag($0.rawValue) }
                }
                if coordinator.behaviour == .pause {
                    Toggle("Resume Spotify after the video", isOn: $coordinator.resumeAfterVideo)
                }
                if coordinator.behaviour == .duck {
                    VStack(alignment: .leading) {
                        Text("Spotify volume during a video: \(Int(coordinator.duckPercent))% of normal")
                        Slider(value: $coordinator.duckPercent, in: 0...90, step: 5)
                    }
                }
                detail("Only Spotify on this device is paused or lowered. Short pauses (buffering, next video) don't restart the music.")
            }
            Section("Sleep timer") {
                if let end = coordinator.sleepEnds {
                    HStack { Text("Pauses everything in"); Spacer(); Text(end, style: .timer).monospacedDigit() }
                    Button("Turn off", role: .destructive) { coordinator.cancelSleepTimer() }
                } else {
                    HStack {
                        ForEach([15, 30, 45, 60, 90], id: \.self) { m in
                            Button("\(m)m") { coordinator.startSleepTimer(minutes: m) }.buttonStyle(.bordered)
                        }
                    }
                }
                detail("Pauses Spotify and every playing tab when the time is up.")
            }
            Section("Now playing button") {
                Toggle("Show the Now playing button in the menu bar", isOn: $showMediaHub)
                Toggle("Also list paused tabs", isOn: $showPaused)
                detail("One click shows every tab with video or audio (YouTube, Twitch, SoundCloud, Spotify Web …) and Spotify: play or pause each one, play only that one, and set its volume. Hold the button to pause everything.")
            }
            #if os(macOS)
            Section("Keyboard") {
                LabeledContent("Play / pause Spotify", value: "⌥⌘P")
                LabeledContent("Next / previous track", value: "⌥⌘→ / ⌥⌘←")
                LabeledContent("Spotify volume", value: "⌥⌘↑ / ⌥⌘↓")
                LabeledContent("Pause everything", value: "⌥⌘.")
            }
            #endif
        }
        .formStyle(.grouped)
    }
}

// MARK: - Bovenbalk automatisch verbergen

enum AutoHideMode: String, CaseIterable, Identifiable {
    case off, whilePlaying, always
    var id: String { rawValue }
    var title: String {
        switch self {
        case .off: "Never"
        case .whilePlaying: "While a video plays"
        case .always: "Always"
        }
    }
}
enum AutoHideParts: String, CaseIterable, Identifiable {
    case both, tabs, buttons
    var id: String { rawValue }
    var title: String {
        switch self {
        case .both: "Tabs and buttons"
        case .tabs: "Only the tabs"
        case .buttons: "Only the buttons"
        }
    }
}

/// Houdt bij of de balk(en) zichtbaar zijn. Verbergt na een instelbare tijd zonder activiteit;
/// muis naar de rand, tikken op de rand, of eroverheen bewegen toont ze meteen weer.
@MainActor
final class ChromeAutoHide: ObservableObject {
    static let shared = ChromeAutoHide()
    @Published private(set) var hidden = false
    private var task: Task<Void, Never>?
    private var hovering = false
    private let d = UserDefaults.standard

    var mode: AutoHideMode { AutoHideMode(rawValue: d.string(forKey: "autoHideModeV20") ?? "off") ?? .off }
    var parts: AutoHideParts { AutoHideParts(rawValue: d.string(forKey: "autoHidePartsV20") ?? "both") ?? .both }
    var delay: Double { d.object(forKey: "autoHideDelayV20") as? Double ?? 3 }
    var revealOnEdge: Bool { d.object(forKey: "autoHideRevealEdgeV20") as? Bool ?? true }

    var tabsHidden: Bool { hidden && parts != .buttons }
    var buttonsHidden: Bool { hidden && parts != .tabs }

    private var anyPlaying: Bool {
        BrowserWorkspace.registry.allObjects.contains { $0.tabs.contains { $0.session.isPlaying } }
    }

    /// Iets gedaan met de balk / rand → tonen en de afteltijd opnieuw starten.
    func reveal() {
        if hidden { hidden = false }
        schedule()
    }
    func setHovering(_ value: Bool) {
        hovering = value
        if value { task?.cancel(); if hidden { hidden = false } } else { schedule() }
    }
    func settingsChanged() { reveal() }
    func playbackChanged() { schedule() }

    func schedule() {
        task?.cancel()
        let shouldAutoHide: Bool = switch mode {
        case .off: false
        case .always: true
        case .whilePlaying: anyPlaying
        }
        guard shouldAutoHide else { if hidden { hidden = false }; return }
        let wait = max(0.5, delay)
        task = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(wait))
            guard let self, !Task.isCancelled, !self.hovering else { return }
            self.hidden = true
        }
    }
}

/// Onzichtbare strook aan de rand die de balk weer laat verschijnen (hover op Mac, tik op iOS).
struct AutoHideRevealZone: View {
    var height: CGFloat = 6
    @ObservedObject private var chrome = ChromeAutoHide.shared
    var body: some View {
        Color.black.opacity(0.001)
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { chrome.reveal() }
            #if os(macOS)
            .onHover { if $0 { chrome.reveal() } }
            #endif
            .accessibilityLabel("Show tabs and buttons")
            .accessibilityAddTraits(.isButton)
    }
}

struct AutoHideSettings: View {
    @AppStorage("autoHideModeV20") private var mode = AutoHideMode.off.rawValue
    @AppStorage("autoHidePartsV20") private var parts = AutoHideParts.both.rawValue
    @AppStorage("autoHideDelayV20") private var delay = 3.0
    @AppStorage("autoHideRevealEdgeV20") private var revealEdge = true
    @AppStorage("autoHideAnimationV20") private var animated = true

    var body: some View {
        Form {
            Section {
                Picker("Hide automatically", selection: $mode) {
                    ForEach(AutoHideMode.allCases) { Text($0.title).tag($0.rawValue) }
                }
                Picker("What to hide", selection: $parts) {
                    ForEach(AutoHideParts.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .disabled(mode == AutoHideMode.off.rawValue)
                VStack(alignment: .leading) {
                    Text("Hide after \(String(format: delay < 10 ? "%.1f" : "%.0f", delay)) s without activity")
                    Slider(value: $delay, in: 0.5...15, step: 0.5)
                }
                .disabled(mode == AutoHideMode.off.rawValue)
            } footer: {
                Text("Gives the video and page all the room. Tabs and buttons come back as soon as you need them.")
            }
            Section("Showing them again") {
                #if os(macOS)
                Toggle("Show when the pointer reaches the top edge", isOn: $revealEdge)
                #else
                Toggle("Show when you tap the top or bottom edge", isOn: $revealEdge)
                #endif
                Toggle("Slide in and out (animation)", isOn: $animated)
                detail("Moving over the bar keeps it visible. Opening settings, a menu or typing an address also shows it.")
            }
        }
        .formStyle(.grouped)
        .onChange(of: mode) { _, _ in ChromeAutoHide.shared.settingsChanged() }
        .onChange(of: parts) { _, _ in ChromeAutoHide.shared.settingsChanged() }
        .onChange(of: delay) { _, _ in ChromeAutoHide.shared.settingsChanged() }
    }
}

// MARK: - V21 ene balk (Safari-achtig)

enum LayoutPrefs {
    /// Eén balk met tabs én knoppen: Mac en iPad (op iPhone blijft de knoppenbalk onderaan).
    /// Staan de knoppen ergens anders (ene balk of zijbalk)? Dan geen losse knoppenbalk.
    static func buttonsElsewhere(oneBar: Bool, sidebar: Bool) -> Bool { Self.oneBar(oneBar) || SidebarPrefs.enabled(sidebar) }
    static func oneBar(_ setting: Bool) -> Bool {
        #if os(macOS)
        return setting
        #else
        return setting && UIDevice.current.userInterfaceIdiom == .pad
        #endif
    }
    static var oneBarButtonSize: CGFloat {
        #if os(macOS)
        return 28
        #else
        return 34
        #endif
    }
}

// MARK: - V21 overdracht tussen apparaten

enum HandoffPrefs {
    private static var d: UserDefaults { .standard }
    /// Wissel je naar dit apparaat terwijl het andere speelt: hier automatisch verder spelen.
    static var autoResume: Bool { d.object(forKey: "handoffAutoResumeV21") as? Bool ?? true }
    /// Hoe lang (s) een "speelt nu"-melding bruikbaar blijft.
    static var maxAge: Double { d.object(forKey: "handoffMaxAgeV21") as? Double ?? 900 }
    /// Een klik/tik telt pas als "wisselen" als je dit apparaat zo lang (s) niet gebruikte.
    static var idleBeforeTakeover: Double { d.object(forKey: "handoffIdleV21") as? Double ?? 4 }
    /// Kleine voorsprong (s) om de tijd van het versturen/verwerken goed te maken.
    static var latencyCompensation: Double { d.object(forKey: "handoffLatencyV21") as? Double ?? 0.08 }
}

struct HandoffSettingsSection: View {
    @AppStorage("handoffAutoResumeV21") private var autoResume = true
    @AppStorage("handoffIdleV21") private var idle = 4.0
    @AppStorage("handoffLatencyV21") private var latency = 0.08
    @AppStorage("handoffMaxAgeV21") private var maxAge = 900.0
    @AppStorage("resumeOnLaunchV21") private var resumeOnLaunch = false
    @AppStorage("advancedModeV22") private var advanced = false
    @AppStorage("liveActivityV22") private var liveActivity = true
    var body: some View {
        Section {
            Toggle("Keep playing when JoeToep reopens", isOn: $resumeOnLaunch)
            Toggle("Continue playing when you switch devices", isOn: $autoResume)
            #if os(iOS)
            Toggle("Live Activity on the Lock Screen", isOn: $liveActivity)
            #endif
            if autoResume && advanced {
                VStack(alignment: .leading) {
                    Text("Count a click or tap as switching after \(Int(idle)) s away")
                    Slider(value: $idle, in: 1...30, step: 1)
                }
                VStack(alignment: .leading) {
                    Text("Timing compensation: \(Int(latency * 1000)) ms")
                    Slider(value: $latency, in: 0...0.5, step: 0.01)
                }
                Picker("Only if the other device played within", selection: $maxAge) {
                    Text("2 minutes").tag(120.0); Text("5 minutes").tag(300.0); Text("15 minutes").tag(900.0); Text("1 hour").tag(3600.0)
                }
            }
        } header: { Text("Switching devices") } footer: {
            Text("Open JoeToep on your iPhone while the Mac plays (or the other way round): the video continues here right away at the same moment, and the other device pauses and sends its exact time so both line up to a fraction of a second.")
        }
    }
}

// MARK: - V21 zijbalk en zwevende zoekbalk (instellingen)

struct SidebarAndCommandBarSettings: View {
    @AppStorage("sidebarTabsV21") private var sidebar = false
    @AppStorage("sidebarHiddenV21") private var sidebarHidden = false
    @AppStorage("sidebarWidthV21") private var width = 250.0
    @AppStorage("sidebarPinnedColumnsV21") private var pinnedColumns = 4
    @AppStorage("sidebarShowNowPlayingV21") private var showNowPlaying = true
    @AppStorage("sidebarShowURLV21") private var showURL = true
    @AppStorage("sidebarCompactRowsV21") private var compactRows = false
    @AppStorage("commandBarNewTabV21") private var overlayNewTab = true
    @AppStorage("commandBarAddressV21") private var overlayAddress = true
    @AppStorage("commandBarTintV21") private var tint = 0.12
    @AppStorage("commandBarSuggestionsV21") private var suggestions = 8
    @AppStorage("commandBarShowTabsV21") private var showTabs = true
    @AppStorage("commandBarShowHistoryV21") private var showHistory = true
    @AppStorage("commandBarTabToSearchV21") private var tabToSearch = true
    @AppStorage("newTabPlatformV192") private var defaultPlatform = MediaPlatform.youtube.rawValue
    @AppStorage("liquidGlassV21") private var glass = true

    private var sidebarAvailable: Bool {
        #if os(macOS)
        true
        #else
        UIDevice.current.userInterfaceIdiom == .pad
        #endif
    }

    var body: some View {
        Form {
            TabAudioIconSettings()
            if sidebarAvailable {
                Section {
                    Picker("Tabs", selection: $sidebar) {
                        Text("At the top").tag(false)
                        Text("Vertical sidebar (like Arc)").tag(true)
                    }
                    if sidebar {
                        Toggle("Hide sidebar (show it at the left edge)", isOn: $sidebarHidden)
                        VStack(alignment: .leading) {
                            Text("Width: \(Int(width)) pt")
                            Slider(value: $width, in: 190...420, step: 10)
                        }
                        Stepper("Pinned tabs per row: \(pinnedColumns)", value: $pinnedColumns, in: 2...6)
                        Toggle("Address field in the sidebar", isOn: $showURL)
                        Toggle("Now playing at the bottom", isOn: $showNowPlaying)
                        Toggle("Compact rows", isOn: $compactRows)
                    }
                } header: { Text("Tab layout") } footer: {
                    Text("Sidebar: pin tabs to the top as tiles, make groups (right-click a tab › Move to group), drag tabs between groups, and press ⌘S to hide or show the sidebar. \"Clear\" closes all loose tabs.")
                }
            }
            Section {
                Toggle("Liquid Glass (tabs, sidebar, panels)", isOn: $glass)
            } header: { Text("Look") }
            Section {
                Toggle("New tab opens a floating search bar", isOn: $overlayNewTab)
                Toggle("Clicking the address opens it too", isOn: $overlayAddress)
                Picker("Search on", selection: $defaultPlatform) {
                    ForEach(MediaPlatform.allCases) { Text($0.title).tag($0.rawValue) }
                }
                Toggle("Platform name + Tab searches there", isOn: $tabToSearch)
                Toggle("Dashboard in the new tab overlay", isOn: Binding(get: { OverlayLayoutStore.shared.dashboardEnabled },
                                                                          set: { OverlayLayoutStore.shared.dashboardEnabled = $0 }))
                Button("Reset overlay layout") { OverlayLayoutStore.shared.reset() }
                Toggle("Suggest open tabs", isOn: $showTabs)
                Toggle("Suggest favourites & history", isOn: $showHistory)
                Stepper("Suggestions: \(suggestions)", value: $suggestions, in: 3...15)
                VStack(alignment: .leading) {
                    Text("Page tint behind the bar: \(Int(tint * 100))%")
                    Slider(value: $tint, in: 0...0.5, step: 0.02)
                }
            } header: { Text("Search bar (⌘T / ⌘L)") } footer: {
                Text("Type “youtube”, “spotify”, “twitch”, “sc” (SoundCloud) … and press Tab: what you type next is searched there. Without a platform JoeToep searches YouTube (or what you pick above).")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - V21 opstarten

enum LaunchPrefs {
    static let started = ProcessInfo.processInfo.systemUptime
    /// De eerste 10 s na het opstarten van de app.
    static var isLaunchPhase: Bool { ProcessInfo.processInfo.systemUptime - started < 10 }
    /// Na opnieuw openen van de app de laatste video meteen laten doorspelen (standaard uit).
    static var resumeOnLaunch: Bool { UserDefaults.standard.object(forKey: "resumeOnLaunchV21") as? Bool ?? false }
}

// MARK: - V21 Liquid Glass

enum GlassPrefs {
    /// Glas-effect voor tabs, zijbalk en zwevende panelen (standaard aan).
    static var enabled: Bool { UserDefaults.standard.object(forKey: "liquidGlassV21") as? Bool ?? true }
}
