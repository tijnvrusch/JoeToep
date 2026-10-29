// V26 — De zichtbare kant van de Arc/Dia-functies: de tabstapel met Split View, Peek (zwevend voorbeeld),
// de Space-kiezer en -bewerker, en de Zap-balk. De logica zit in BrowserWorkspace (Spaces/Split/Peek) en in
// de pure modellen (Models/BrowserSpaces.swift, Models/SplitLayout.swift).
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Tabstapel (één tab, of twee naast/onder elkaar)

/// Alle tabs van het venster op elkaar gestapeld; zichtbaar is de geselecteerde tab, of in Split View beide
/// panelen. Elke tab houdt zijn eigen identiteit (ForEach op tab.id): de webview wordt bij het openen of sluiten
/// van Split View nooit opnieuw gemaakt, er wordt alleen een ander kader gegeven.
struct WorkspaceTabStack: View {
    @ObservedObject var workspace: BrowserWorkspace
    @ObservedObject var settings: AppSettings
    let actions: WorkspaceActions
    @AppStorage(V26Prefs.Key.splitHeaders) private var showHeaders = true
    @AppStorage(V26Prefs.Key.splitGap) private var gap = 6.0
    @AppStorage(V26Prefs.Key.splitFocusRing) private var focusRing = true
    @AppStorage(V26Prefs.Key.splitDimUnfocused) private var dimUnfocused = 0.0
    @Environment(\.joeToepTheme) private var theme

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let pair = workspace.split
            let arrangement = pair.map { SplitLayout.arrangement(width: size.width, height: size.height, prefersVertical: $0.vertical) } ?? .single
            let usedGap = pair == nil || arrangement == .single ? 0 : min(max(gap, 0), 24)
            let frames = SplitLayout.frames(width: size.width, height: size.height, fraction: pair?.fraction ?? 0.5,
                                            arrangement: arrangement, gap: usedGap)
            ZStack(alignment: .topLeading) {
                ForEach(workspace.tabs) { tab in
                    let rect = paneRect(tab, pair: pair, arrangement: arrangement, frames: frames, size: size)
                    let visible = rect != nil
                    let inSplit = pair != nil && arrangement != .single && visible
                    let focused = tab.id == workspace.selectedID
                    let frame = rect ?? CGRect(origin: .zero, size: size)
                    VStack(spacing: 0) {
                        if inSplit && showHeaders {
                            SplitPaneHeader(workspace: workspace, tab: tab, focused: focused)
                        }
                        TabPlayerView(settings: settings, session: tab.session, selected: visible, actions: actions)
                            .overlay {
                                // Eerste klik op het paneel zonder focus = focus geven (daarna werkt de pagina gewoon).
                                if inSplit && !focused {
                                    Color.black.opacity(max(dimUnfocused, 0.001))
                                        .contentShape(Rectangle())
                                        .onTapGesture { workspace.focusPane(tab.id) }
                                        .accessibilityLabel("Focus this pane")
                                }
                            }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: inSplit ? 8 : 0, style: .continuous))
                    .overlay {
                        if inSplit && focused && focusRing {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(theme.accent.opacity(0.85), lineWidth: 2)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(width: max(0, frame.width), height: max(0, frame.height))
                    .offset(x: frame.minX, y: frame.minY)
                    .opacity(visible ? 1 : 0)
                    .allowsHitTesting(visible)
                    .accessibilityHidden(!visible)
                    .zIndex(focused ? 1 : (visible ? 0.5 : 0))
                }
                if let pair, arrangement != .single {
                    SplitDivider(workspace: workspace, pair: pair, arrangement: arrangement, frames: frames, size: size, gap: usedGap)
                        .zIndex(3)
                }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
        }
    }

    /// Kader van een tab, of nil als hij nu niet op het scherm staat.
    private func paneRect(_ tab: BrowserTab, pair: SplitPair?, arrangement: SplitLayout.Arrangement,
                          frames: (first: CGRect, second: CGRect), size: CGSize) -> CGRect? {
        guard let pair, arrangement != .single, pair.contains(tab.id) else {
            return tab.id == workspace.selectedID ? CGRect(origin: .zero, size: size) : nil
        }
        return tab.id == pair.primary ? frames.first : frames.second
    }
}

/// Kopje boven elk paneel: titel, focus, wisselen, draaien en sluiten.
struct SplitPaneHeader: View {
    @ObservedObject var workspace: BrowserWorkspace
    @ObservedObject var tab: BrowserTab
    let focused: Bool
    @Environment(\.joeToepTheme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: tab.session.isPlaying ? "speaker.wave.2.fill" : (NavigationPolicy.isPlaybackPage(tab.currentURL) ? "play.rectangle" : "globe"))
                .font(.caption).foregroundStyle(focused ? theme.accent : theme.secondary)
            Text(tab.title).font(.caption.weight(focused ? .semibold : .regular)).lineLimit(1)
                .foregroundStyle(focused ? theme.foreground : theme.secondary)
            Spacer(minLength: 4)
            headerButton("arrow.left.arrow.right", "Swap panes") { workspace.swapSplitPanes() }
            headerButton(workspace.split?.vertical == true ? "rectangle.split.2x1" : "rectangle.split.1x2", "Side by side / stacked") {
                workspace.toggleSplitOrientation()
            }
            headerButton("arrow.up.left.and.arrow.down.right", "Show only this tab") { workspace.closeSplit(keeping: tab.id) }
            headerButton("xmark", "Close this tab") { workspace.close(tab) }
        }
        .padding(.horizontal, 8)
        .frame(height: 26)
        .background(theme.foreground.opacity(focused ? 0.1 : 0.04))
        .contentShape(Rectangle())
        .onTapGesture { workspace.focusPane(tab.id) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("split.header")
    }

    private func headerButton(_ symbol: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 10, weight: .semibold)).frame(width: 20, height: 20).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.secondary)
        .help(help)
        .accessibilityLabel(help)
    }
}

/// De versleepbare scheidingslijn tussen de panelen. Dubbelklik = weer 50/50.
struct SplitDivider: View {
    @ObservedObject var workspace: BrowserWorkspace
    let pair: SplitPair
    let arrangement: SplitLayout.Arrangement
    let frames: (first: CGRect, second: CGRect)
    let size: CGSize
    let gap: Double
    @State private var dragStart: Double?
    @State private var hovering = false
    @Environment(\.joeToepTheme) private var theme

    private var sideBySide: Bool { arrangement == .sideBySide }
    private var hitThickness: CGFloat { max(CGFloat(gap), 10) }

    var body: some View {
        let length = sideBySide ? size.height : size.width
        ZStack {
            Color.black.opacity(0.001)
            Capsule()
                .fill(hovering || dragStart != nil ? theme.accent.opacity(0.9) : theme.foreground.opacity(0.28))
                .frame(width: sideBySide ? 4 : 40, height: sideBySide ? 40 : 4)
        }
        .frame(width: sideBySide ? hitThickness : length, height: sideBySide ? length : hitThickness)
        .contentShape(Rectangle())
        .offset(x: sideBySide ? frames.first.maxX + CGFloat(gap) / 2 - hitThickness / 2 : 0,
                y: sideBySide ? 0 : frames.first.maxY + CGFloat(gap) / 2 - hitThickness / 2)
        #if os(macOS)
        .onHover { inside in
            hovering = inside
            if inside { (sideBySide ? NSCursor.resizeLeftRight : NSCursor.resizeUpDown).push() } else { NSCursor.pop() }
        }
        #endif
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { value in
                    let start = dragStart ?? pair.fraction
                    if dragStart == nil { dragStart = pair.fraction }
                    let total = Double(sideBySide ? size.width : size.height) - gap
                    let moved = Double(sideBySide ? value.translation.width : value.translation.height)
                    workspace.setSplitFraction(SplitLayout.fraction(start: start, translation: moved, total: total))
                }
                .onEnded { _ in
                    dragStart = nil
                    // De laatst gekozen verdeling is de standaard voor de volgende Split View.
                    if let fraction = workspace.split?.fraction { UserDefaults.standard.set(fraction, forKey: V26Prefs.Key.splitFraction) }
                }
        )
        .simultaneousGesture(TapGesture(count: 2).onEnded { workspace.setSplitFraction(0.5) })
        .accessibilityLabel("Resize split view")
        .accessibilityIdentifier("split.divider")
    }
}

// MARK: - Peek

/// Zwevend voorbeeld van een link boven de huidige pagina. Esc of klik ernaast = sluiten; "Open as tab"
/// (⌘↩) maakt er een gewone tab van, "Split" zet hem naast de huidige tab.
struct PeekOverlay: View {
    @ObservedObject var workspace: BrowserWorkspace
    @ObservedObject var tab: BrowserTab
    @ObservedObject var settings: AppSettings
    @AppStorage(V26Prefs.Key.peekSize) private var sizeSetting = 0.84
    @AppStorage(V26Prefs.Key.peekDim) private var dim = 0.28
    @AppStorage(V26Prefs.Key.peekCloseOutside) private var closeOutside = true
    @Environment(\.joeToepTheme) private var theme

    private var isPhone: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }

    var body: some View {
        GeometryReader { geometry in
            let fraction = isPhone ? 0.96 : min(max(sizeSetting, 0.5), 0.95)
            ZStack {
                Color.black.opacity(min(max(dim, 0), 0.8))
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { if closeOutside { workspace.closePeek() } }
                    .accessibilityLabel("Close preview")
                VStack(spacing: 0) {
                    header
                    TabPlayerView(settings: settings, session: tab.session, selected: true, actions: nil)
                }
                .frame(width: geometry.size.width * fraction, height: geometry.size.height * fraction)
                .background(theme.background)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(theme.foreground.opacity(0.12), lineWidth: 1))
                .shadow(color: .black.opacity(0.35), radius: 28, y: 10)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .closesOnEscape { workspace.closePeek() }
        .accessibilityIdentifier("peek")
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "eye").foregroundStyle(theme.accent)
            VStack(alignment: .leading, spacing: 0) {
                Text(tab.title).font(.callout.weight(.semibold)).lineLimit(1)
                if let host = tab.currentURL?.host { Text(host).font(.caption2).foregroundStyle(theme.secondary).lineLimit(1) }
            }
            Spacer(minLength: 8)
            if let url = tab.currentURL {
                peekButton("link", "Copy Link") { Clipboard.copy(url) }
            }
            if workspace.splitAvailable && !isPhone {
                peekButton("rectangle.split.2x1", "Open in Split View") { workspace.expandPeek(split: true) }
            }
            Button { workspace.expandPeek() } label: {
                Label("Open as Tab", systemImage: "arrow.up.forward.square").font(.caption.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: .command)
            .help("Open as Tab (⌘↩)")
            .accessibilityIdentifier("peek.expand")
            peekButton("xmark", "Close (Esc)") { workspace.closePeek() }
                .accessibilityIdentifier("peek.close")
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(theme.foreground.opacity(0.05))
    }

    private func peekButton(_ symbol: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 12, weight: .semibold)).frame(width: 26, height: 26).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.secondary)
        .help(help)
        .accessibilityLabel(help)
    }
}

// MARK: - Spaces

/// Icoon van een Space: SF Symbol of emoji, in de kleur van de Space (gevuld als hij actief is).
struct SpaceIcon: View {
    let space: BrowserSpace
    var active = false
    var size: CGFloat = 22
    @Environment(\.joeToepTheme) private var theme

    var body: some View {
        let color = TabGroup.color(named: space.color)
        ZStack {
            Circle().fill(active ? color.opacity(0.9) : color.opacity(0.16))
            if space.symbolIsEmoji {
                Text(space.symbol).font(.system(size: size * 0.55))
            } else {
                Image(systemName: space.symbol).font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(active ? Color.white : color)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(space.name)
    }
}

/// Rij met alle Spaces onderaan de zijbalk (zoals Arc), plus "+".
struct SpaceSwitcherBar: View {
    @ObservedObject var workspace: BrowserWorkspace
    @Environment(\.joeToepTheme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(workspace.spaces.enumerated()), id: \.element.id) { index, space in
                Button { withAnimation(Motion.quick()) { workspace.switchSpace(to: space.id) } } label: {
                    SpaceIcon(space: space, active: space.id == workspace.activeSpaceID, size: 24)
                }
                .buttonStyle(.plain)
                .help(index < 9 ? "\(space.name) (⌃\(index + 1))" : space.name)
                .contextMenu { SpaceMenuItems(workspace: workspace, space: space) }
                .accessibilityIdentifier("space.\(index)")
            }
            Button { withAnimation(Motion.quick()) { _ = workspace.addSpace() } } label: {
                Image(systemName: "plus").font(.system(size: 11, weight: .bold)).frame(width: 24, height: 24)
                    .background(Circle().fill(theme.foreground.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.secondary)
            .help("New Space")
            .accessibilityIdentifier("space.new")
            .disabled(workspace.spaces.count >= SpaceLogic.maximumCount)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
    }
}

/// Menu-items voor één Space (contextmenu in de zijbalk en het Space-menu in de tabbalk).
struct SpaceMenuItems: View {
    @ObservedObject var workspace: BrowserWorkspace
    let space: BrowserSpace

    var body: some View {
        if space.id != workspace.activeSpaceID {
            Button { workspace.switchSpace(to: space.id) } label: { Label("Switch to \(space.name)", systemImage: "arrow.right.circle") }
        }
        Button { workspace.editingSpaceID = space.id } label: { Label("Edit Name, Icon and Colour…", systemImage: "pencil") }
        Menu("Colour") {
            ForEach(SpaceLogic.palette, id: \.self) { color in
                Button(color.capitalized) { workspace.updateSpace(space.id, color: color) }
            }
        }
        Button { workspace.moveSpace(space.id, by: -1) } label: { Label("Move Left", systemImage: "arrow.left") }
        Button { workspace.moveSpace(space.id, by: 1) } label: { Label("Move Right", systemImage: "arrow.right") }
        if workspace.spaces.count > 1 {
            Divider()
            Button { workspace.deleteSpace(space.id, closingTabs: false) } label: { Label("Delete Space (keep tabs)", systemImage: "trash") }
            Button(role: .destructive) { workspace.deleteSpace(space.id, closingTabs: true) } label: {
                Label("Delete Space and Close Its Tabs", systemImage: "trash.fill")
            }
        }
    }
}

/// Kop boven de tabs in de zijbalk: icoon + naam van de actieve Space.
struct SpaceTitleRow: View {
    @ObservedObject var workspace: BrowserWorkspace
    @Environment(\.joeToepTheme) private var theme

    var body: some View {
        let space = workspace.activeSpace
        HStack(spacing: 8) {
            SpaceIcon(space: space, active: true, size: 20)
            Text(space.name).font(.callout.weight(.bold)).lineLimit(1)
            Spacer(minLength: 0)
            Menu {
                SpaceMenuItems(workspace: workspace, space: space)
                Divider()
                Button { _ = workspace.addSpace() } label: { Label("New Space", systemImage: "plus") }
            } label: {
                Image(systemName: "ellipsis").font(.caption.weight(.bold)).frame(width: 22, height: 22).contentShape(Rectangle())
            }
            #if os(macOS)
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            #endif
            .fixedSize()
            .foregroundStyle(theme.secondary)
        }
        .padding(.horizontal, 6).padding(.top, 2)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { workspace.editingSpaceID = space.id }
        .accessibilityIdentifier("space.title")
    }
}

/// Space-knop links in de tabbalk (als de zijbalk uit staat): menu met alle Spaces.
struct SpaceMenuChip: View {
    @ObservedObject var workspace: BrowserWorkspace
    var showName = true
    @Environment(\.joeToepTheme) private var theme

    var body: some View {
        let space = workspace.activeSpace
        Menu {
            ForEach(Array(workspace.spaces.enumerated()), id: \.element.id) { index, item in
                Button { workspace.switchSpace(to: item.id) } label: {
                    if item.id == workspace.activeSpaceID { Label(item.name, systemImage: "checkmark") }
                    else { Text(index < 9 ? "\(item.name)  ⌃\(index + 1)" : item.name) }
                }
            }
            Divider()
            Button { _ = workspace.addSpace() } label: { Label("New Space", systemImage: "plus") }
            Button { workspace.editingSpaceID = space.id } label: { Label("Edit \(space.name)…", systemImage: "pencil") }
        } label: {
            HStack(spacing: 5) {
                SpaceIcon(space: space, active: true, size: 20)
                if showName { Text(space.name).font(.caption.weight(.semibold)).lineLimit(1).foregroundStyle(theme.foreground) }
            }
            .padding(.horizontal, showName ? 6 : 2).frame(height: 28)
            .background(Capsule().fill(TabGroup.color(named: space.color).opacity(0.12)))
        }
        #if os(macOS)
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        #endif
        .fixedSize()
        .help("Spaces")
        .accessibilityIdentifier("space.chip")
    }
}

/// Naam, icoon en kleur van een Space aanpassen.
struct SpaceEditorSheet: View {
    @ObservedObject var workspace: BrowserWorkspace
    let spaceID: UUID
    @State private var name = ""
    @State private var emoji = ""
    @Environment(\.dismiss) private var dismiss

    private var space: BrowserSpace? { workspace.spaces.first { $0.id == spaceID } }

    var body: some View {
        NavigationStack {
            Form {
                if let space {
                    Section {
                        HStack(spacing: 12) {
                            SpaceIcon(space: space, active: true, size: 40)
                            TextField("Name", text: $name)
                                .font(.title3.weight(.semibold))
                                .onSubmit { workspace.updateSpace(spaceID, name: name) }
                        }
                    }
                    Section("Colour") {
                        HStack(spacing: 10) {
                            ForEach(SpaceLogic.palette, id: \.self) { color in
                                Button { workspace.updateSpace(spaceID, color: color) } label: {
                                    Circle().fill(TabGroup.color(named: color)).frame(width: 24, height: 24)
                                        .overlay(Circle().strokeBorder(Color.primary.opacity(space.color == color ? 0.9 : 0), lineWidth: 2))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(color.capitalized)
                            }
                        }
                    }
                    Section("Icon") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
                            ForEach(SpaceLogic.suggestedSymbols, id: \.self) { symbol in
                                Button { workspace.updateSpace(spaceID, symbol: symbol) } label: {
                                    Image(systemName: symbol).frame(width: 30, height: 30)
                                        .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(space.symbol == symbol ? 0.18 : 0.05)))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        HStack {
                            TextField("Or type one emoji", text: $emoji)
                                .onSubmit { applyEmoji() }
                            Button("Use", action: applyEmoji).disabled(emoji.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    if workspace.spaces.count > 1 {
                        Section {
                            Button("Delete Space (tabs move to the previous Space)", role: .destructive) {
                                workspace.deleteSpace(spaceID, closingTabs: false); dismiss()
                            }
                        }
                    }
                } else {
                    Text("This Space no longer exists.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Space")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { workspace.updateSpace(spaceID, name: name); dismiss() }
                }
            }
        }
        .onAppear { name = space?.name ?? "" }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 460)
        #endif
    }

    private func applyEmoji() {
        let value = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = value.first else { return }
        workspace.updateSpace(spaceID, symbol: String(first))
        emoji = ""
    }
}

// MARK: - Zap

/// Balk onderaan de pagina zolang Zap aan staat: uitleg, Undo en Done.
struct ZapBanner: View {
    @ObservedObject var session: WebSession
    @Environment(\.joeToepTheme) private var theme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "bolt.fill").foregroundStyle(.white)
                .frame(width: 26, height: 26).background(Circle().fill(Color.red))
            VStack(alignment: .leading, spacing: 1) {
                Text("Zap").font(.callout.weight(.bold))
                Text(session.zapsThisSession == 0 ? "Click anything on the page to hide it" : "\(session.zapsThisSession) hidden — saved for this site")
                    .font(.caption).foregroundStyle(theme.secondary)
            }
            Spacer(minLength: 8)
            Button("Undo") { session.undoZap() }
                .disabled(session.zapsThisSession == 0)
            Button("Done") { session.stopZap() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .frame(maxWidth: 560)
        .joeToepGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 16, y: 6)
        .padding(.bottom, 18).padding(.horizontal, 12)
        .accessibilityIdentifier("zap.banner")
    }
}

/// Tekst naar het klembord (de assistent kopieert hiermee zijn antwoord).
enum TextClipboard {
    static func copy(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}
