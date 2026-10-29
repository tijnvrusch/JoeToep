// V26 — Panelen voor de Arc/Dia-functies: de pagina-assistent (zijpaneel/blad), de Boost-bewerker per
// website en de instellingenpagina "Spaces, Split View & Boosts".
import SwiftUI
import Combine
#if os(iOS)
import UIKit
#endif

// MARK: - Pagina-assistent

struct PageAssistantPanel: View {
    @ObservedObject var workspace: BrowserWorkspace
    @StateObject private var model = PageAssistantModel()
    @AppStorage(V26Prefs.Key.assistantShowKeywords) private var showKeywords = true
    @AppStorage(V26Prefs.Key.assistantAppleIntelligence) private var useApple = true
    @FocusState private var questionFocused: Bool
    @Environment(\.joeToepTheme) private var theme

    private var session: WebSession { workspace.selected.session }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.4)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    pageCard
                    Picker("Mode", selection: $model.mode) {
                        ForEach(PageDigest.Mode.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .onChange(of: model.mode) { _, mode in if mode != .question { model.run(mode) } else { questionFocused = true } }
                    if model.mode == .question { questionField }
                    result
                    if showKeywords && !model.keywords.isEmpty { keywordChips }
                }
                .padding(14)
            }
            footer
        }
        .background(theme.background)
        .onAppear { model.load(from: session) }
        .onChange(of: workspace.selectedID) { _, _ in model.load(from: session) }
        // Nieuwe pagina in deze tab (ook binnen YouTube) → opnieuw lezen zodra hij even stilstaat.
        .onReceive(session.$currentURL.dropFirst().debounce(for: .milliseconds(700), scheduler: RunLoop.main)) { _ in
            model.load(from: session)
        }
        .accessibilityIdentifier("assistant")
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles").foregroundStyle(theme.accent)
            Text("Page Assistant").font(.headline)
            Spacer()
            Button { model.load(from: session, force: true) } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.plain).foregroundStyle(theme.secondary).help("Read the page again")
            Button { workspace.showAssistant = false } label: { Image(systemName: "xmark") }
                .buttonStyle(.plain).foregroundStyle(theme.secondary).help("Close (⌘E)")
                .accessibilityIdentifier("assistant.close")
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    @ViewBuilder private var pageCard: some View {
        if model.loading {
            HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Reading the page…").foregroundStyle(theme.secondary) }
        } else if let page = model.page {
            VStack(alignment: .leading, spacing: 4) {
                Text(page.title.isEmpty ? (page.url?.host ?? "This page") : page.title).font(.callout.weight(.semibold)).lineLimit(3)
                HStack(spacing: 10) {
                    if let host = page.url?.host { Label(host, systemImage: "globe") }
                    Label("\(PageDigest.readingMinutes(page)) min read", systemImage: "clock")
                }
                .font(.caption).foregroundStyle(theme.secondary)
            }
        }
    }

    private var questionField: some View {
        HStack(spacing: 8) {
            TextField("Ask about this page…", text: $model.question)
                .textFieldStyle(.roundedBorder)
                .focused($questionFocused)
                .onSubmit { model.run(.question, question: model.question) }
            Button { model.run(.question, question: model.question) } label: { Image(systemName: "arrow.up.circle.fill").font(.title3) }
                .buttonStyle(.plain).foregroundStyle(theme.accent)
                .disabled(model.question.trimmingCharacters(in: .whitespaces).isEmpty || model.page == nil)
        }
    }

    @ViewBuilder private var result: some View {
        if model.busy {
            HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Thinking…").foregroundStyle(theme.secondary) }
        } else if let message = model.message {
            Text(message).font(.callout).foregroundStyle(theme.secondary)
        } else if !model.lines.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(model.lines.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        if model.mode == .keyPoints { Text("•").foregroundStyle(theme.accent) }
                        Text(line).font(.callout).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    }
                }
                HStack {
                    Label(model.engine.title, systemImage: model.engine.symbol).font(.caption2).foregroundStyle(theme.secondary)
                    Spacer()
                    Button { TextClipboard.copy(model.plainText) } label: { Label("Copy", systemImage: "doc.on.doc").font(.caption) }
                        .buttonStyle(.bordered)
                }
            }
        } else if model.page != nil && model.mode != .question {
            Button { model.run(model.mode) } label: { Label(model.mode.title, systemImage: "sparkles") }.buttonStyle(.borderedProminent)
        }
    }

    private var keywordChips: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Topics").font(.caption.weight(.semibold)).foregroundStyle(theme.secondary)
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(model.keywords, id: \.self) { word in
                        Button {
                            model.mode = .question
                            model.question = "What does the page say about \(word)?"
                            model.run(.question, question: word)
                        } label: {
                            Text(word).font(.caption).padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Capsule().fill(theme.foreground.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill").font(.caption2)
            Text(PageAssistantModel.appleIntelligenceAvailable && useApple
                 ? "Runs on this device with Apple Intelligence. Nothing is sent anywhere."
                 : "Runs on this device. Nothing is sent anywhere.")
                .font(.caption2)
        }
        .foregroundStyle(theme.secondary)
        .padding(.horizontal, 14).padding(.vertical, 8)
    }
}

// MARK: - Boost-bewerker

struct BoostEditorView: View {
    @ObservedObject var workspace: BrowserWorkspace
    @ObservedObject var session: WebSession
    @State private var boost = SiteBoost(site: "")
    @State private var loaded = false
    @State private var customCSS = ""
    @State private var cssTask: Task<Void, Never>?
    @State private var hexText = ""
    @AppStorage(V26Prefs.Key.boostsEnabled) private var boostsEnabled = true
    @Environment(\.dismiss) private var dismiss

    private struct Swatch: Hashable { let name: String; let hex: String }
    private static let backgrounds: [Swatch] = [Swatch(name: "Black", hex: "#000000"), Swatch(name: "YouTube dark", hex: "#0F0F0F"),
                                                Swatch(name: "Graphite", hex: "#1C1C1E"), Swatch(name: "Night blue", hex: "#0B1E2D"),
                                                Swatch(name: "Paper", hex: "#FDF6E3"), Swatch(name: "White", hex: "#FFFFFF")]

    var body: some View {
        NavigationStack {
            Form {
                if let site = session.boostSite {
                    Section {
                        Toggle(isOn: $boost.enabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Boost \(site)").font(.headline)
                                Text(boost.changeCount == 0 ? "No changes yet" : "\(boost.changeCount) change\(boost.changeCount == 1 ? "" : "s") on this site")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        if !boostsEnabled {
                            Label("Boosts are turned off in Settings › Spaces, Split View & Boosts.", systemImage: "exclamationmark.triangle")
                                .font(.caption).foregroundStyle(.orange)
                        }
                    }
                    Section {
                        Button {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { session.startZap() }
                        } label: { Label("Zap Elements…", systemImage: "bolt.fill") }
                        if !boost.hiddenSelectors.isEmpty {
                            ForEach(boost.hiddenSelectors, id: \.self) { selector in
                                HStack {
                                    Text(selector).font(.system(.caption, design: .monospaced)).lineLimit(2)
                                    Spacer()
                                    Button { boost.hiddenSelectors.removeAll { $0 == selector } } label: { Image(systemName: "minus.circle.fill") }
                                        .buttonStyle(.plain).foregroundStyle(.red).accessibilityLabel("Show again")
                                }
                            }
                        }
                    } header: { Text("Hidden elements") } footer: {
                        Text("Zap: click anything on the page to hide it on this site. Remove an entry to show it again.")
                    }
                    let presets = BoostPreset.allCases.filter { $0.applies(to: site) }
                    Section("Quick changes") {
                        ForEach(presets) { preset in
                            Toggle(isOn: Binding(
                                get: { boost.presets.contains(preset) },
                                set: { on in
                                    if on { if !boost.presets.contains(preset) { boost.presets.append(preset) } }
                                    else { boost.presets.removeAll { $0 == preset } }
                                })) { Label(preset.title, systemImage: preset.symbol) }
                        }
                    }
                    Section("Look") {
                        Picker("Font", selection: $boost.font) { ForEach(BoostFont.allCases) { Text($0.title).tag($0) } }
                        Picker("Colour filter", selection: $boost.filter) { ForEach(BoostFilter.allCases) { Text($0.title).tag($0) } }
                        Picker("Background", selection: Binding(get: { boost.backgroundHex ?? "" },
                                                                set: { boost.backgroundHex = $0.isEmpty ? nil : $0 })) {
                            Text("Website's own").tag("")
                            ForEach(Self.backgrounds, id: \.hex) { Text($0.name).tag($0.hex) }
                            if let hex = boost.backgroundHex, !Self.backgrounds.contains(where: { $0.hex == hex }) { Text(hex).tag(hex) }
                        }
                        HStack {
                            TextField("Custom colour (#RRGGBB)", text: $hexText)
                                .onSubmit(applyHex)
                            Button("Use", action: applyHex).disabled(SiteBoost.validHex(hexText) == nil)
                        }
                        Toggle("Limit reading width", isOn: Binding(get: { boost.readingWidth != nil },
                                                                    set: { boost.readingWidth = $0 ? (boost.readingWidth ?? 820) : nil }))
                        if let width = boost.readingWidth {
                            VStack(alignment: .leading) {
                                Text("Maximum width: \(width) pt")
                                Slider(value: Binding(get: { Double(width) }, set: { boost.readingWidth = SiteBoost.clampWidth(Int($0)) }),
                                       in: 480...2400, step: 20)
                            }
                        }
                    }
                    Section {
                        TextEditor(text: $customCSS)
                            .font(.system(.caption, design: .monospaced))
                            .frame(minHeight: 120)
                            .autocorrectionDisabled()
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                            .onChange(of: customCSS) { _, text in
                                // Pas toepassen als je even stopt met typen (niet bij elke toetsaanslag alle tabs herladen).
                                cssTask?.cancel()
                                cssTask = Task { @MainActor in
                                    try? await Task.sleep(for: .milliseconds(450))
                                    guard !Task.isCancelled else { return }
                                    boost.customCSS = text
                                }
                            }
                    } header: { Text("Custom CSS") } footer: {
                        Text("Applies to \(site) only. @import is ignored. Use !important to override the site's own styles.")
                    }
                    Section {
                        Button("Reset \(site)", role: .destructive) {
                            BoostStore.remove(site: site)
                            boost = SiteBoost(site: site); customCSS = ""
                        }
                        .disabled(boost.isEmpty)
                    }
                } else {
                    Text("Boosts work on websites. Open a page first.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Boost")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { commitCSS(); dismiss() } } }
        }
        .onAppear(perform: load)
        .onChange(of: boost) { _, value in
            guard loaded, !value.site.isEmpty else { return }
            BoostStore.save(value)
        }
        .onDisappear { commitCSS() }
        #if os(macOS)
        .frame(minWidth: 480, idealWidth: 540, minHeight: 560, idealHeight: 680)
        #endif
    }

    private func load() {
        guard let site = session.boostSite else { return }
        boost = BoostStore.loadAll()[site] ?? SiteBoost(site: site)
        customCSS = boost.customCSS
        DispatchQueue.main.async { loaded = true }
    }
    private func applyHex() {
        guard let hex = SiteBoost.validHex(hexText) else { return }
        boost.backgroundHex = hex; hexText = ""
    }
    private func commitCSS() {
        cssTask?.cancel()
        if loaded, boost.customCSS != customCSS { boost.customCSS = customCSS }
    }
}

// MARK: - Instellingen

struct V26Settings: View {
    @AppStorage(V26Prefs.Key.spacesEnabled) private var spacesEnabled = true
    @AppStorage(V26Prefs.Key.spaceSwitcher) private var spaceSwitcher = true
    @AppStorage(V26Prefs.Key.spaceTint) private var spaceTint = true
    @AppStorage(V26Prefs.Key.spaceTintStrength) private var spaceTintStrength = 0.14
    @AppStorage(V26Prefs.Key.pinnedEverywhere) private var pinnedEverywhere = true
    @AppStorage(V26Prefs.Key.spaceShortcuts) private var spaceShortcuts = true
    @AppStorage(V26Prefs.Key.spaceNameInTabBar) private var spaceNameInTabBar = true
    @AppStorage(V26Prefs.Key.splitEnabled) private var splitEnabled = true
    @AppStorage(V26Prefs.Key.splitFraction) private var splitFraction = 0.5
    @AppStorage(V26Prefs.Key.splitVertical) private var splitVertical = false
    @AppStorage(V26Prefs.Key.splitHeaders) private var splitHeaders = true
    @AppStorage(V26Prefs.Key.splitGap) private var splitGap = 6.0
    @AppStorage(V26Prefs.Key.splitFocusRing) private var splitFocusRing = true
    @AppStorage(V26Prefs.Key.splitDimUnfocused) private var splitDim = 0.0
    @AppStorage(V26Prefs.Key.peekEnabled) private var peekEnabled = true
    @AppStorage(V26Prefs.Key.peekShiftClick) private var peekShiftClick = true
    @AppStorage(V26Prefs.Key.peekSize) private var peekSize = 0.84
    @AppStorage(V26Prefs.Key.peekDim) private var peekDim = 0.28
    @AppStorage(V26Prefs.Key.peekCloseOutside) private var peekCloseOutside = true
    @AppStorage(V26Prefs.Key.boostsEnabled) private var boostsEnabled = true
    @AppStorage(V26Prefs.Key.zapHighlight) private var zapHighlight = true
    @AppStorage(V26Prefs.Key.assistantEnabled) private var assistantEnabled = true
    @AppStorage(V26Prefs.Key.assistantAppleIntelligence) private var assistantApple = true
    @AppStorage(V26Prefs.Key.assistantSentences) private var assistantSentences = 5
    @AppStorage(V26Prefs.Key.assistantWidth) private var assistantWidth = 340.0
    @AppStorage(V26Prefs.Key.assistantAutoSummary) private var assistantAutoSummary = true
    @AppStorage(V26Prefs.Key.assistantShowKeywords) private var assistantKeywords = true
    @State private var boostCount = BoostStore.loadAll().count
    @State private var confirmClearBoosts = false

    var body: some View {
        Form {
            Section {
                SettingToggle("Spaces", isOn: $spacesEnabled)
                if spacesEnabled {
                    SettingToggle("Pinned tabs in every Space", isOn: $pinnedEverywhere)
                    SettingToggle("Space switcher in the sidebar", isOn: $spaceSwitcher)
                    SettingToggle("Space name in the tab bar", isOn: $spaceNameInTabBar)
                    SettingToggle("Tint the sidebar with the Space colour", isOn: $spaceTint)
                    if spaceTint {
                        VStack(alignment: .leading) {
                            Text("Tint strength: \(Int(spaceTintStrength * 100))%")
                            Slider(value: $spaceTintStrength, in: 0...0.5, step: 0.02)
                        }
                    }
                    SettingToggle("Keyboard shortcuts for Spaces (⌃1…⌃9)", isOn: $spaceShortcuts)
                }
            } header: { Text("Spaces") } footer: {
                Text("Separate sets of tabs for different parts of your life, each with its own name, icon and colour. Switch with the icons at the bottom of the sidebar, the Space button in the tab bar, ⌃1…⌃9 or ⌃⌘[ / ⌃⌘]. Right-click a tab › Move to Space.")
            }
            Section {
                SettingToggle("Split View", isOn: $splitEnabled)
                if splitEnabled {
                    VStack(alignment: .leading) {
                        Text("Default split: \(Int(splitFraction * 100))% / \(100 - Int(splitFraction * 100))%")
                        Slider(value: $splitFraction, in: SplitLayout.minimumFraction...SplitLayout.maximumFraction, step: 0.05)
                    }
                    SettingToggle("Stack panes vertically by default", isOn: $splitVertical)
                    SettingToggle("Title bar above each pane", isOn: $splitHeaders)
                    SettingToggle("Highlight the focused pane", isOn: $splitFocusRing)
                    VStack(alignment: .leading) {
                        Text("Space between panes: \(Int(splitGap)) pt")
                        Slider(value: $splitGap, in: 0...24, step: 1)
                    }
                    VStack(alignment: .leading) {
                        Text("Dim the other pane: \(Int(splitDim * 100))%")
                        Slider(value: $splitDim, in: 0...0.5, step: 0.05)
                    }
                }
            } header: { Text("Split View") } footer: {
                Text("Two tabs side by side (⌘⇧\\, or right-click a tab › Open in Split View). Drag the divider to resize, double-click it for 50/50. Click a pane to give it the keyboard and buttons; a video in the other pane keeps playing until another video starts.")
            }
            Section {
                SettingToggle("Peek", isOn: $peekEnabled)
                if peekEnabled {
                    #if os(macOS)
                    SettingToggle("Shift-click a link to peek", isOn: $peekShiftClick)
                    #endif
                    VStack(alignment: .leading) {
                        Text("Preview size: \(Int(peekSize * 100))%")
                        Slider(value: $peekSize, in: 0.5...0.95, step: 0.01)
                    }
                    VStack(alignment: .leading) {
                        Text("Dim the page behind: \(Int(peekDim * 100))%")
                        Slider(value: $peekDim, in: 0...0.8, step: 0.02)
                    }
                    SettingToggle("Click outside the preview closes it", isOn: $peekCloseOutside)
                }
            } header: { Text("Peek") } footer: {
                Text("Opens a link in a floating preview above the current page: Open in Peek in the link menu, or Shift-click on the Mac. Esc closes it, ⌘↩ keeps it as a tab.")
            }
            Section {
                SettingToggle("Boosts", isOn: $boostsEnabled)
                if boostsEnabled {
                    SettingToggle("Highlight elements while zapping", isOn: $zapHighlight)
                    LabeledContent("Boosted websites", value: "\(boostCount)")
                    if boostCount > 0 {
                        Button("Remove All Boosts…", role: .destructive) { confirmClearBoosts = true }
                    }
                }
            } header: { Text("Boosts") } footer: {
                Text("Change any website for good: hide parts of it (Zap), quick fixes such as hiding comments or end screens, another font, a colour filter or your own CSS. Open with ⌘⌥B or the ⋯ menu.")
            }
            Section {
                SettingToggle("Page assistant", isOn: $assistantEnabled)
                if assistantEnabled {
                    SettingToggle("Use Apple Intelligence for the page assistant", isOn: $assistantApple)
                    if !PageAssistantModel.appleIntelligenceAvailable {
                        Text("Apple Intelligence is not available on this device; the built-in offline method is used.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Stepper("Summary length: \(assistantSentences) sentences", value: $assistantSentences, in: 2...12)
                    SettingToggle("Summarise automatically when opened", isOn: $assistantAutoSummary)
                    SettingToggle("Show topics", isOn: $assistantKeywords)
                    #if os(macOS)
                    VStack(alignment: .leading) {
                        Text("Panel width: \(Int(assistantWidth)) pt")
                        Slider(value: $assistantWidth, in: 280...560, step: 10)
                    }
                    #endif
                }
            } header: { Text("Page assistant") } footer: {
                Text("Summarises the page, lists its key points or answers a question about it (⌘E). Everything runs on this device.")
            }
            Section {
                Button("Restore Defaults for These Features") { V26Prefs.reset() }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Remove the Boosts of all \(boostCount) websites?", isPresented: $confirmClearBoosts, titleVisibility: .visible) {
            Button("Remove All", role: .destructive) { BoostStore.saveAll([:]); boostCount = 0 }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear { boostCount = BoostStore.loadAll().count }
    }
}
