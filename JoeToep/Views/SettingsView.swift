import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// V15 settings: grouped pages with every option adjustable.
struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var session: WebSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.joeToepTheme) private var theme
    @State private var confirmClear = false
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Image("IconPreview" + AppIconController.shared.selection).resizable()
                            .frame(width: 54, height: 54).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("JoeToep \(AppConstants.version)").font(.headline)
                            Text(SigningInfo.summary).font(.caption)
                                .foregroundStyle(SigningInfo.expiresSoon ? .orange : .secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("Settings") {
                    link("Appearance", "paintbrush", .pink) { AppearanceSettings(settings: settings) }
                    link("Tabs", "square.on.square", .blue) { TabSettings(settings: settings) }
                    link("Playback & Picture in Picture", "pip", .red) { PlaybackSettings(settings: settings, session: session) }
                    link("Ad blocking", "hand.raised", .orange) { AdBlockSettings(settings: settings, session: session) }
                    link("SponsorBlock", "forward.end.alt", .green) { SponsorBlockSettingsView(settings: settings, session: session) }
                    link("Browser & privacy", "globe", .teal) {
                        BrowserSettings(settings: settings, session: session, confirmClear: $confirmClear)
                    }
                    link("Menu bar & layout", "menubar.rectangle", .indigo) { LayoutSettings(settings: settings) }
                    link("Focus filters", "line.3.horizontal.decrease.circle", .purple) { FocusSettings(settings: settings) }
                    link("Diagnostics", "stethoscope", .gray) { DiagnosticsSettings(settings: settings, session: session) }
                }
                Section {
                    Button("Reset all preferences…", role: .destructive) { confirmReset = true }
                    detail("Resets every setting to its default. Tabs, bookmarks, history and sign-in stay.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("settings.done")
                }
            }
        }
        .confirmationDialog("Clear cookies, cache and website storage?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear data", role: .destructive, action: session.clearWebsiteData)
            Button("Cancel", role: .cancel) {}
        } message: { Text("You will be signed out.") }
        .confirmationDialog("Reset all JoeToep preferences?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive, action: settings.resetPreferences)
            Button("Cancel", role: .cancel) {}
        }
    }

    private func link<Destination: View>(_ title: String, _ symbol: String, _ color: Color,
                                         @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink {
            destination()
                .formStyle(.grouped)
                .navigationTitle(title)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.accessibilityIdentifier("settings.done") }
                }
        } label: {
            Label {
                Text(title)
            } icon: {
                Image(systemName: symbol).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 26, height: 26).background(color.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
        }
        .accessibilityIdentifier("settings.page." + title)
    }
}

@ViewBuilder
func detail(_ text: String) -> some View {
    Text(text).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
}

// MARK: - Appearance

private struct AppearanceSettings: View {
    @ObservedObject var settings: AppSettings
    var body: some View {
        Form {
            Section("Theme") {
                Picker("Theme", selection: $settings.themeStyle) {
                    ForEach(ThemeStyle.allCases) { style in
                        Label { Text(style.title) } icon: {
                            Circle().fill(style.background).overlay(Circle().stroke(.gray.opacity(0.4))).frame(width: 14, height: 14)
                        }.tag(style)
                    }
                }
                Picker("Accent colour", selection: $settings.accentChoice) {
                    ForEach(AccentChoice.allCases) { choice in
                        Label { Text(choice.title) } icon: {
                            Circle().fill(choice.color(custom: settings.customAccentHex)).frame(width: 14, height: 14)
                        }.tag(choice)
                    }
                }
                if settings.accentChoice == .custom {
                    ColorPicker("Custom accent", selection: Binding(
                        get: { Color(hexString: settings.customAccentHex) ?? .red },
                        set: { settings.customAccentHex = $0.hexString }), supportsOpacity: false)
                }
                detail("The theme colours JoeToep's menu bar, tabs and settings. YouTube itself stays in its dark theme.")
            }
            Section("Icons in the app") {
                Picker("Style", selection: $settings.iconVariant) {
                    ForEach(IconVariant.allCases) { Text($0.title).tag($0) }
                }
                Picker("Weight", selection: $settings.iconWeight) {
                    ForEach(IconWeightChoice.allCases) { Text($0.title).tag($0) }
                }
                Picker("Colouring", selection: $settings.iconRendering) {
                    ForEach(IconRendering.allCases) { Text($0.title).tag($0) }
                }
                IconStylePreview(theme: settings.theme)
            }
            Section("Tabs") {
                Picker("Tab shape", selection: $settings.tabShape) {
                    ForEach(TabShape.allCases) { Text($0.title).tag($0) }
                }
                Picker("Tab text", selection: $settings.tabTextSize) {
                    ForEach(TabTextSize.allCases) { Text($0.title).tag($0) }
                }
                Picker("Close buttons", selection: $settings.tabCloseButtons) {
                    ForEach(TabCloseButtons.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Show tab icons", isOn: $settings.showTabIcons)
            }
            Section("Motion") {
                Picker("Animations", selection: $settings.animationStyle) {
                    ForEach(AnimationStyle.allCases) { Text($0.title).tag($0) }
                }
                detail("Tabs, menus and sheets animate with this curve. JoeToep never lowers animation quality to save battery.")
            }
            Section("App icon") {
                IconPickerGrid()
                if let error = AppIconController.shared.error { Text(error).font(.caption).foregroundStyle(.red) }
                #if os(macOS)
                detail("Changes the Dock icon while JoeToep runs (drawn on the standard macOS icon shape). Finder shows the bundled Classic icon.")
                #else
                detail("iOS confirms an icon change with a short system message.")
                #endif
            }
        }
    }
}

private struct IconStylePreview: View {
    let theme: JoeToepTheme
    var body: some View {
        HStack(spacing: 18) {
            ForEach(["house", "rectangle.stack", "arrow.clockwise", "pip", "gearshape", "bookmark"], id: \.self) { symbol in
                Image(systemName: symbol).themedIcon(theme, size: 19, active: symbol == "pip")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(theme.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Tabs

private struct TabSettings: View {
    @ObservedObject var settings: AppSettings
    var body: some View {
        Form {
            Section("Automatic tab summary") {
                Toggle("Summarise video titles in tabs", isOn: $settings.aiTabSummary)
                    .accessibilityIdentifier("settings.aiTabSummary")
                Picker("Length", selection: $settings.tabSummaryLength) {
                    ForEach(TabSummaryLength.allCases) { Text($0.title).tag($0) }
                }.disabled(!settings.aiTabSummary)
                Toggle("Use Apple Intelligence when available", isOn: $settings.useAppleIntelligence)
                    .disabled(!settings.aiTabSummary)
                LabeledContent("Apple Intelligence on this device", value: TabTitleSummarizer.appleIntelligenceAvailable ? "Available" : "Not available")
                detail("On: a short summary of the video in a few words, made on-device (Apple Intelligence) or with JoeToep's built-in shortener. Off: the tab shows the full video title. Tabs never just say “YouTube”.")
            }
            Section("Closing") {
                Picker("Close inactive tabs after", selection: $settings.tabLifetime) {
                    ForEach(TabLifetime.allCases) { Text($0.title).tag($0) }
                }
                detail("Tabs you have not opened or played for this long close automatically in the background. Pinned tabs, the current tab, a playing tab and PiP are never closed. Closed tabs can be reopened (⌘⇧T or the + menu).")
            }
            Section("Opening") {
                Toggle("Open new tabs next to the current tab", isOn: $settings.openNewTabsNextToCurrent)
                Picker("New tab page", selection: $settings.startPage) {
                    ForEach(StartPage.allCases) { Text($0.title).tag($0) }
                }
                detail("Tap the selected tab to type a web address or search. Long-press (iPhone/iPad) or right-click (Mac) a video or link for “Open in New Tab and Switch” and “Open in New Tab”. Right-click / long-press a tab to pin it.")
            }
        }
    }
}

// MARK: - Playback

private struct PlaybackSettings: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var session: WebSession
    var body: some View {
        Form {
            Section("Picture in Picture") {
                Toggle("Automatic PiP when switching apps", isOn: $settings.automaticPiP)
                    .accessibilityIdentifier("settings.autoPiP")
                Toggle("Show PiP button in menu bar", isOn: $settings.showPiPButton)
                    .accessibilityIdentifier("settings.showPiPButton")
                Picker("PiP return button opens", selection: $settings.pipReturnTarget) {
                    ForEach(PiPReturnTarget.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Keep playing when returning from PiP", isOn: $settings.pipReturnKeepsPlaying)
                Toggle("Start PiP after leaving fullscreen", isOn: $settings.pipOnFullscreenExit)
                Toggle("Keep PiP when returning to JoeToep", isOn: $settings.keepPiPOnReturn)
                Toggle("Protect background playback", isOn: $settings.backgroundProtection)
                Toggle("Enable direct PiP fallback", isOn: $settings.pipFallbackEnabled)
                    .accessibilityIdentifier("settings.pipFallback")
                detail("The PiP window's return button (top right) takes the video straight to fullscreen and keeps it playing. Hold the PiP button for 0.3 s to reset PiP.")
                #if os(macOS)
                Toggle("Bring JoeToep forward when native PiP ends", isOn: $settings.activateMacOnPiPExit)
                Toggle("Automatic floating video fallback", isOn: $settings.macFloatingFallback)
                #else
                detail("Also keep “Start PiP Automatically” enabled in iOS Settings › General › Picture in Picture.")
                #endif
            }
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .phone {
                Section("Rotation (iPhone)") {
                    Toggle("Fullscreen when rotating to landscape", isOn: $settings.fullscreenOnLandscape)
                    Toggle("Leave fullscreen when rotating back to portrait", isOn: $settings.exitFullscreenOnPortrait)
                    Toggle("Instant rotation (keep the page in portrait)", isOn: $settings.portraitLockForRotation)
                        .disabled(!settings.fullscreenOnLandscape)
                    Toggle("YouTube fullscreen instead of Apple player", isOn: $settings.phoneElementFullscreen)
                    detail("Instant rotation keeps the page itself in portrait, so turning the phone goes straight into landscape fullscreen in one smooth movement.")
                }
            }
            #endif
            Section("Fullscreen & video") {
                #if os(macOS)
                Picker("Fullscreen player", selection: $settings.macFullscreenMode) {
                    ForEach(MacFullscreenMode.allCases) { Text($0.title).tag($0) }
                }
                #else
                Toggle("Use Apple player (disable to use Safe Fullscreen)", isOn: $settings.nativeFullscreen)
                    .accessibilityIdentifier("settings.nativeFullscreen")
                Toggle("Rotate fullscreen to landscape", isOn: $settings.rotateOnFullscreen)
                Toggle("Return to portrait after fullscreen", isOn: $settings.returnToPortrait)
                #endif
                Toggle("Open videos in fullscreen automatically", isOn: $settings.automaticFullscreen)
                    .accessibilityIdentifier("settings.automaticFullscreen")
                Toggle("Fastest transitions", isOn: $settings.instantTransitions)
                Toggle("Keep the screen on while a video plays", isOn: $settings.keepScreenAwake)
                Toggle("Turn off video captions", isOn: $settings.disableCaptions)
                Toggle("Turn off thumbnail preview captions", isOn: $settings.disablePreviewCaptions)
            }
            Section("Quality") {
                Picker("Resolution preference", selection: $settings.quality) {
                    ForEach(PlaybackQualityPreference.allCases) { Text($0.title).tag($0) }
                }
                Picker("Video sizing", selection: $settings.videoFit) {
                    ForEach(VideoFit.allCases) { Text($0.title).tag($0) }
                }
                Picker("Pinch gesture", selection: $settings.pinchMode) {
                    ForEach(PinchMode.allCases) { Text($0.title).tag($0) }
                }
                Button("Reset video zoom", action: session.resetVideoZoom)
                #if os(iOS)
                Toggle("Apple streaming engine (360p: video AirPlay + inline auto-PiP)", isOn: $settings.appleStreamingEngine)
                    .accessibilityIdentifier("settings.appleEngine")
                detail("Off (default): MediaSource up to 1080p/4K. On: a single 360p Apple HLS stream with video AirPlay and native inline PiP. Applies to new tabs. Engine now: \(session.appleStreamingEngine ? "Apple HLS" : "MediaSource").")
                #endif
            }
            Section("Media controls") {
                detail("Control Center, the Lock Screen and the ⏯ key (F8 on Mac) control the video through the system's Now Playing. JoeToep becomes the Now Playing app whenever its video plays or was the last thing playing; when another app (Spotify, Podcasts) starts playing afterwards, iOS and macOS hand the controls to that app until JoeToep plays again. No app can take the controls back without starting playback itself.")
            }
        }
    }
}

// MARK: - Ad blocking

private struct AdBlockSettings: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var session: WebSession
    var body: some View {
        Form {
            Section {
                Toggle("Block ads", isOn: $settings.blockAds)
                Toggle("Hide ad cards and promoted tiles", isOn: $settings.hideAdCards)
            }
            Section("Strictness") {
                ForEach(AdBlockLevel.allCases) { level in
                    Button { settings.adBlockLevel = level } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: settings.adBlockLevel == level ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(settings.adBlockLevel == level ? Color.accentColor : .secondary)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(level.title).font(.body.weight(.medium))
                                Text(level.explanation).font(.caption).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!settings.blockAds)
                    .accessibilityAddTraits(settings.adBlockLevel == level ? .isSelected : [])
                }
                detail("Changes apply on the next page load (tap Refresh). If a video stops working or YouTube shows a warning, go one level lower; if ads come back, go one level higher.")
            }
            Section("Experimental rules") {
                Toggle("Latest compatible EasyList rules", isOn: $settings.experimentalFilters)
                    .accessibilityIdentifier("settings.experimentalFilters")
                Button(session.isUpdatingFilters ? "Checking source…" : "Check for latest experimental rules", action: session.updateExperimentalFilters)
                    .disabled(session.isUpdatingFilters)
                Text(session.experimentalFilterStatus).font(.caption).textSelection(.enabled)
                detail("Imports only supported YouTube ad-container selectors from EasyList (The EasyList authors · CC BY-SA 3.0).")
            }
        }
    }
}

// MARK: - SponsorBlock

private struct SponsorBlockSettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var session: WebSession
    private func binding(_ category: SponsorBlockCategory) -> Binding<SponsorBlockMode> {
        Binding(get: { settings.sponsorBlock.mode(category) },
                set: { settings.sponsorBlock.modes[category.rawValue] = $0 })
    }
    var body: some View {
        Form {
            Section {
                Toggle("SponsorBlock", isOn: $settings.sponsorBlock.enabled)
                    .accessibilityIdentifier("settings.sponsorBlock")
                LabeledContent("This video", value: session.sponsorStatus)
                LabeledContent("Segments skipped", value: "\(UserDefaults.standard.integer(forKey: SponsorBlockService.statsSkippedKey))")
                LabeledContent("Time saved", value: Self.duration(UserDefaults.standard.double(forKey: SponsorBlockService.statsSavedKey)))
                detail("Skips sponsors and other segments using the community SponsorBlock database. Only a 4-character hash prefix of the video ID is sent; segments are matched on your device.")
            }
            Section("Categories") {
                ForEach(SponsorBlockCategory.allCases) { category in
                    Picker(selection: binding(category)) {
                        ForEach(SponsorBlockMode.allCases) { Text($0.title).tag($0) }
                    } label: {
                        HStack(spacing: 8) {
                            Circle().fill(Color(hexString: category.colorHex) ?? .green).frame(width: 10, height: 10)
                            Text(category.title)
                        }
                    }
                }
            }.disabled(!settings.sponsorBlock.enabled)
            Section("Behaviour") {
                Toggle("Show a notice with Undo after skipping", isOn: $settings.sponsorBlock.showNotice)
                Stepper("Notice duration: \(Int(settings.sponsorBlock.noticeSeconds)) s", value: $settings.sponsorBlock.noticeSeconds, in: 2...10, step: 1)
                Toggle("Show segments in the progress bar", isOn: $settings.sponsorBlock.showMarkers)
                Toggle("Skip each segment only once", isOn: $settings.sponsorBlock.skipOnlyOnce)
                Picker("Ignore segments shorter than", selection: $settings.sponsorBlock.minimumDuration) {
                    ForEach([0.0, 1, 2, 3, 5, 10], id: \.self) { Text($0 == 0 ? "Never" : "\(Int($0)) s").tag($0) }
                }
            }.disabled(!settings.sponsorBlock.enabled)
            Section("Server") {
                TextField("Server", text: $settings.sponsorBlock.serverURL)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never).keyboardType(.URL)
                    #endif
                Button("Use the official server") { settings.sponsorBlock.serverURL = "https://sponsor.ajay.app" }
            }.disabled(!settings.sponsorBlock.enabled)
        }
    }
    static func duration(_ seconds: Double) -> String {
        let total = Int(seconds)
        if total < 60 { return "\(total) s" }
        if total < 3600 { return "\(total / 60) min \(total % 60) s" }
        return "\(total / 3600) h \((total % 3600) / 60) min"
    }
}

// MARK: - Browser

private struct BrowserSettings: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var session: WebSession
    @Binding var confirmClear: Bool
    @ObservedObject private var library = BrowserLibrary.shared
    var body: some View {
        Form {
            Section("Browsing") {
                Toggle("Open other websites in JoeToep", isOn: $settings.openWebLinksInApp)
                Picker("Search with", selection: $settings.searchEngine) {
                    ForEach(SearchEngine.allCases) { Text($0.title).tag($0) }
                }
                Picker("Website layout", selection: $settings.sitePresentation) {
                    ForEach(SitePresentation.allCases) { Text($0.title).tag($0) }
                }
                HStack {
                    Text("Page scale")
                    Slider(value: $settings.pageZoom, in: 0.75...1.5, step: 0.05)
                    Text("\(Int(settings.pageZoom * 100))%").monospacedDigit().frame(width: 46)
                }
                detail("Type in the address bar (tap the selected tab): a web address opens directly, anything else searches with the engine above. Per tab: ⋯ › Request Desktop/Mobile Website and zoom.")
            }
            Section("History & privacy") {
                Toggle("Remember browsing history", isOn: $settings.recordHistory)
                LabeledContent("History entries", value: "\(library.history.count)")
                LabeledContent("Bookmarks", value: "\(library.bookmarks.count)")
                Button("Clear history", role: .destructive) { library.clearHistory() }
                    .disabled(library.history.isEmpty)
                Button("Clear website data…", role: .destructive) { confirmClear = true }
                    .accessibilityIdentifier("settings.clearData")
                detail("Private tabs (⌘⇧N, or the + menu) keep no history, cookies or cache and are not restored after a restart.")
            }
        }
    }
}

// MARK: - Layout

private struct LayoutSettings: View {
    @ObservedObject var settings: AppSettings
    var body: some View {
        Form {
            Section("Size") {
                Picker("Menu bar buttons", selection: $settings.toolbarDensity) {
                    ForEach(ToolbarDensity.allCases) { Text($0.title).tag($0) }
                }
                detail("Eight sizes. Cozy, Medium and Roomy sit just below Large.")
            }
            Section("Buttons") {
                #if os(iOS)
                Toggle("Show JoeToep / #yolo", isOn: $settings.showBrand)
                #endif
                Toggle("Show Back and Forward buttons", isOn: $settings.showNavigationControls)
                Toggle("Show History button", isOn: $settings.showHistoryButton)
                Toggle("Show Playlist / Watch later button", isOn: $settings.showPlaylistButton)
                Toggle("Show Bookmark button", isOn: $settings.showBookmarkButton)
                Toggle("Show More (⋯) browser menu", isOn: $settings.showMoreMenu)
                Toggle("Show connection and playback status", isOn: $settings.showConnectionStatus)
                Toggle("Edge-to-edge webpage", isOn: $settings.edgeToEdge)
            }
        }
    }
}

// MARK: - Focus filters

private struct FocusSettings: View {
    @ObservedObject var settings: AppSettings
    var body: some View {
        Form {
            Section {
                Toggle("Hide Shorts", isOn: $settings.blockShortsNavigation)
                Toggle("Hide posts and announcements", isOn: $settings.blockPostsNavigation)
                Toggle("Hide Premium / members-only cards", isOn: $settings.blockPremiumDestinations)
                Toggle("Recover a terminated web process", isOn: $settings.recoverWebProcess)
                detail("Filters apply on the next page load; playback is not reloaded.")
            }
        }
    }
}

// MARK: - Diagnostics

private struct DiagnosticsSettings: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var session: WebSession
    var body: some View {
        Form {
            Section("Status") {
                LabeledContent("Version", value: AppConstants.version)
                LabeledContent("Signing", value: SigningInfo.summary)
                LabeledContent("Content filters", value: session.filterStatus)
                LabeledContent("Resolution", value: session.mediaResolution ?? "Not measured")
                LabeledContent("Player quality", value: session.measuredQuality.isEmpty ? "Not exposed" : session.measuredQuality)
                LabeledContent("SponsorBlock", value: session.sponsorStatus)
                Text(session.mediaCompatibilityStatus).font(.caption)
            }
            Section("Picture in Picture") {
                Text(session.diagnostic).font(.caption).textSelection(.enabled)
                Text("Native PiP: " + session.nativePiPDiagnostic).font(.caption2).textSelection(.enabled)
                Text(session.recentLifecycle).font(.caption2.monospaced()).textSelection(.enabled)
                Button("Copy PiP diagnostics", action: session.copyPiPDiagnostics)
            }
        }
    }
}

extension Color {
    /// "#RRGGBB" in sRGB (custom accent colour).
    var hexString: String {
        #if os(iOS)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        #else
        let color = NSColor(self).usingColorSpace(.sRGB) ?? .red
        let r = color.redComponent, g = color.greenComponent, b = color.blueComponent
        #endif
        func clamp(_ v: CGFloat) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", clamp(r), clamp(g), clamp(b))
    }
}
