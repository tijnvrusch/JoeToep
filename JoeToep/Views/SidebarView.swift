// V21 — Verticale tabs in een zijbalk, zoals Arc en Dia (Mac en iPad).
//
// Van boven naar beneden: venster-knopjes + navigatie · adres-"pil" (opent de zwevende zoekbalk)
// · vastgezette tabs als tegels · groepen (in-/uitklapbaar, met kleur) · losse tabs · "+ Nieuwe tab"
// · onderaan de overige knoppen en een mini Now Playing. Slepen zet tabs in een groep, bij de
// vastgezette tabs of weer los. De zijbalk kan in-/uitklappen (⌘S) en automatisch verschijnen
// als je de muis naar de linkerrand beweegt.
import SwiftUI
#if os(iOS)
import UIKit
#endif

enum SidebarPrefs {
    static func enabled(_ setting: Bool) -> Bool {
        #if os(macOS)
        return setting
        #else
        return setting && UIDevice.current.userInterfaceIdiom == .pad
        #endif
    }
}

struct SidebarView: View {
    @ObservedObject var workspace: BrowserWorkspace
    @ObservedObject var settings: AppSettings
    var actions: WorkspaceActions
    var topInset: CGFloat
    /// Mac: ruimte voor de venster-knopjes links in de bovenste rij.
    var leadingInset: CGFloat = 0
    @AppStorage("sidebarWidthV21") private var width = 250.0
    @AppStorage("sidebarPinnedColumnsV21") private var pinnedColumns = 4
    @AppStorage("sidebarShowNowPlayingV21") private var showNowPlaying = true
    @AppStorage("sidebarShowURLV21") private var showURL = true
    @AppStorage("sidebarCompactRowsV21") private var compactRows = false
    // V26: Spaces (Arc).
    @AppStorage(V26Prefs.Key.spacesEnabled) private var spacesEnabled = true
    @AppStorage(V26Prefs.Key.spaceSwitcher) private var spaceSwitcher = true
    @AppStorage(V26Prefs.Key.spaceTint) private var spaceTint = true
    @AppStorage(V26Prefs.Key.spaceTintStrength) private var spaceTintStrength = 0.14
    @AppStorage(V26Prefs.Key.pinnedEverywhere) private var pinnedEverywhere = true
    @AppStorage(V26Prefs.Key.splitEnabled) private var splitEnabled = true
    @State private var renaming: UUID?
    @State private var renameText = ""
    @State private var dropTarget: String?
    /// V22.2: breedte bij het begin van het verslepen van de rand.
    @State private var dragStartWidth: Double?
    @Environment(\.joeToepTheme) private var theme
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 8) {
            header
            if showURL { addressPill }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if !workspace.pinnedTabs.isEmpty || dropTarget == "pinned" { pinnedGrid }
                    if spacesEnabled { SpaceTitleRow(workspace: workspace) }
                    ForEach(workspace.visibleGroups) { group in groupSection(group) }
                    looseSection
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.never)
            footer
        }
        .padding(.top, topInset)
        .frame(width: width)
        .background {
            if GlassPrefs.enabled { Rectangle().fill(.ultraThinMaterial).overlay(theme.background.opacity(0.55)) }
            else { theme.background.opacity(0.94) }
        }
        // V26: de zijbalk kleurt mee met de actieve Space (zoals Arc).
        .background(alignment: .top) {
            if spacesEnabled && spaceTint {
                LinearGradient(colors: [TabGroup.color(named: workspace.activeSpace.color).opacity(min(max(spaceTintStrength, 0), 0.5)),
                                        TabGroup.color(named: workspace.activeSpace.color).opacity(min(max(spaceTintStrength, 0), 0.5) * 0.35)],
                               startPoint: .top, endPoint: .bottom)
                    .allowsHitTesting(false)
                    .animation(Motion.fade(0.3), value: workspace.activeSpaceID)
            }
        }
        .overlay(alignment: .trailing) { resizeHandle }
        .accessibilityIdentifier("sidebar")
    }

    // MARK: Bovenkant

    private var header: some View {
        HStack(spacing: 0) {
            PlayerControlBar(session: workspace.selected.session, settings: settings, availableWidth: width, actions: actions,
                             showSettings: actions.openSettings, part: .leading, fixedButtonSize: 28)
                .id(workspace.selectedID)
            Spacer(minLength: 0)
        }
        .padding(.leading, 6 + leadingInset).padding(.trailing, 6)
        .frame(height: 34)
        .background(WindowDragArea())
    }

    private var addressPill: some View {
        Button { workspace.requestEditAddress() } label: {
            HStack(spacing: 8) {
                Image(systemName: workspace.selected.isPrivate ? "eyeglasses" : "magnifyingglass").font(.caption)
                Text(workspace.selected.currentURL?.host?.replacingOccurrences(of: "www.", with: "") ?? "Search or enter address")
                    .font(.callout).lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(theme.secondary)
            .padding(.horizontal, 10).frame(height: 32)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(theme.foreground.opacity(0.07)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .help("Search or enter address (⌘L)")
    }

    // MARK: Vastgezette tabs (tegels)

    private var pinnedGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: max(2, pinnedColumns)), spacing: 6) {
            ForEach(workspace.pinnedTabs) { tab in
                PinnedTile(tab: tab, session: tab.session, selected: tab.id == workspace.selectedID)
                    .onTapGesture { DispatchQueue.main.async { if Date().timeIntervalSince(TabAudioIcon.lastAction) > 0.4 { workspace.select(tab) } } }
                    .contextMenu { tabMenu(tab) }
                    .draggable(tab.id.uuidString)
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 12).fill(dropTarget == "pinned" ? theme.accent.opacity(0.15) : .clear))
        .dropDestination(for: String.self) { items, _ in
            guard let tab = tab(from: items) else { return false }
            // V22.2: via setPinned → herordenen + opslaan (niet alleen de vlag omzetten).
            workspace.setPinned(tab, true); return true
        } isTargeted: { dropTarget = $0 ? "pinned" : (dropTarget == "pinned" ? nil : dropTarget) }
    }

    // MARK: Groepen

    @ViewBuilder private func groupSection(_ group: TabGroup) -> some View {
        let members = workspace.tabs(in: group.id)
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: group.collapsed ? "chevron.right" : "chevron.down").font(.caption2.weight(.bold))
                    .foregroundStyle(theme.secondary).frame(width: 12)
                Circle().fill(group.swiftUIColor).frame(width: 8, height: 8)
                if renaming == group.id {
                    TextField("Group name", text: $renameText).textFieldStyle(.plain).font(.callout.weight(.semibold))
                        .onSubmit { workspace.renameGroup(group.id, to: renameText); renaming = nil }
                } else {
                    Text(group.name).font(.callout.weight(.semibold)).lineLimit(1)
                }
                Spacer()
                Text("\(members.count)").font(.caption2).foregroundStyle(theme.secondary)
            }
            .padding(.horizontal, 6).padding(.vertical, 5)
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(Motion.quick()) { workspace.toggleGroupCollapsed(group.id) } }
            .contextMenu {
                Button("Rename") { renameText = group.name; renaming = group.id }
                Menu("Colour") {
                    ForEach(TabGroup.palette, id: \.self) { c in Button(c.capitalized) { workspace.recolorGroup(group.id, to: c) } }
                }
                Button("New tab in group") { workspace.addTab(url: nil); workspace.setGroup(workspace.selected, to: group.id) }
                Divider()
                Button("Ungroup tabs") { workspace.removeGroup(group.id, closingTabs: false) }
                Button("Close group", role: .destructive) { workspace.removeGroup(group.id, closingTabs: true) }
            }
            .background(RoundedRectangle(cornerRadius: 8).fill(dropTarget == group.id.uuidString ? group.swiftUIColor.opacity(0.2) : .clear))
            .dropDestination(for: String.self) { items, _ in
                guard let tab = tab(from: items) else { return false }
                workspace.setGroup(tab, to: group.id); return true
            } isTargeted: { dropTarget = $0 ? group.id.uuidString : (dropTarget == group.id.uuidString ? nil : dropTarget) }
            if !group.collapsed {
                ForEach(members) { tab in row(tab, accent: group.swiftUIColor).padding(.leading, 10) }
            }
        }
    }

    private var looseSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Tabs").font(.caption.weight(.semibold)).foregroundStyle(theme.secondary)
                Spacer()
                Button("Clear") { withAnimation(Motion.quick()) { workspace.clearLooseTabs() } }
                    .buttonStyle(.plain).font(.caption).foregroundStyle(theme.secondary)
                    .help("Close all loose tabs (pinned tabs and groups stay)")
            }
            .padding(.horizontal, 6).padding(.top, 4)
            .dropDestination(for: String.self) { items, _ in
                guard let tab = tab(from: items) else { return false }
                // V22.2: via setPinned → herordenen + opslaan.
                workspace.setGroup(tab, to: nil); workspace.setPinned(tab, false); return true
            }
            Button { workspace.requestNewTab() } label: {
                Label("New Tab", systemImage: "plus").font(.callout)
                    .foregroundStyle(theme.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8).frame(height: compactRows ? 28 : 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("sidebar.newTab")
            ForEach(workspace.tabs(in: nil)) { tab in row(tab, accent: nil) }
        }
    }

    private func row(_ tab: BrowserTab, accent: Color?) -> some View {
        SidebarTabRow(tab: tab, session: tab.session, selected: tab.id == workspace.selectedID, compact: compactRows,
                      accent: accent, close: { workspace.close(tab) }, select: { workspace.select(tab) })
            .onTapGesture {
                // V22.2: zelfde bewaking als TabBarView.tapped(): een klik op het geluid-icoontje is geen tab-klik.
                if TabAudioIcon.selecting { workspace.select(tab); return }
                DispatchQueue.main.async { if Date().timeIntervalSince(TabAudioIcon.lastAction) >= 0.4 { workspace.select(tab) } }
            }
            .contextMenu { tabMenu(tab) }
            .draggable(tab.id.uuidString) { Text(tab.title).padding(6) }
            .dropDestination(for: String.self) { items, _ in
                guard let raw = items.first, let id = UUID(uuidString: raw), let moved = workspace.tabs.first(where: { $0.id == id }) else { return false }
                moved.pinned = tab.pinned; moved.groupID = tab.groupID; moved.spaceID = tab.spaceID   // V26: ook dezelfde Space
                return workspace.moveTab(id: id, before: tab.id)
            }
            .middleClick { workspace.close(tab) }
    }

    @ViewBuilder private func tabMenu(_ tab: BrowserTab) -> some View {
        Button { workspace.togglePin(tab) } label: { Label(tab.pinned ? "Unpin" : "Pin to top", systemImage: tab.pinned ? "pin.slash" : "pin") }
        Menu("Move to group") {
            Button("New group…") { let g = workspace.newGroup(with: tab); renameText = g.name; renaming = g.id }
            ForEach(workspace.visibleGroups) { g in Button(g.name) { workspace.setGroup(tab, to: g.id) } }
            if tab.groupID != nil { Divider(); Button("Remove from group") { workspace.setGroup(tab, to: nil) } }
        }
        // V26: naar een andere Space verplaatsen, of naast de huidige tab zetten (Split View).
        if spacesEnabled && workspace.spaces.count > 1 {
            Menu("Move to Space") {
                ForEach(workspace.spaces) { space in
                    Button(space.name) { withAnimation(Motion.quick()) { workspace.moveTab(tab, toSpace: space.id) } }
                        .disabled(space.id == workspace.spaceID(of: tab))
                }
            }
        }
        if splitEnabled && tab.id != workspace.selectedID {
            Button { withAnimation(Motion.quick(0.22)) { workspace.openSplit(with: tab) } } label: {
                Label("Open in Split View", systemImage: "rectangle.split.2x1")
            }
        }
        Button { workspace.duplicate(tab) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
        if !workspace.otherDevices.isEmpty {
            Menu("Continue on…") {
                ForEach(workspace.otherDevices, id: \.id) { d in Button(d.name) { workspace.continuePlayback(of: tab, on: d.id) } }
            }
        }
        if let url = tab.currentURL {
            Button { Clipboard.copy(url) } label: { Label("Copy Link", systemImage: "link") }
            ShareLink(item: url) { Label("Share…", systemImage: "square.and.arrow.up") }
        }
        Divider()
        Button(role: .destructive) { workspace.close(tab) } label: { Label("Close Tab", systemImage: "xmark") }
        Button { workspace.closeOthers(tab) } label: { Label("Close Other Tabs", systemImage: "xmark.square") }
    }

    // MARK: Onderkant

    private var footer: some View {
        VStack(spacing: 6) {
            if showNowPlaying { SidebarNowPlaying(workspace: workspace) }
            if spacesEnabled && spaceSwitcher { SpaceSwitcherBar(workspace: workspace) }
            ScrollView(.horizontal) {
                PlayerControlBar(session: workspace.selected.session, settings: settings, availableWidth: width, actions: actions,
                                 showSettings: actions.openSettings, part: .trailing, fixedButtonSize: 28)
                    .id(workspace.selectedID)
            }
            .scrollIndicators(.never)
            .padding(.horizontal, 6)
        }
        .padding(.bottom, 8)
    }

    private var resizeHandle: some View {
        Rectangle().fill(Color.clear).frame(width: 6).contentShape(Rectangle())
            #if os(macOS)
            .onHover { inside in if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() } }
            #endif
            .gesture(DragGesture(minimumDistance: 1).onChanged { value in
                // V22.2: vanaf de breedte bij het begin van het slepen rekenen (translation is cumulatief).
                let start = dragStartWidth ?? width
                if dragStartWidth == nil { dragStartWidth = width }
                width = min(420, max(190, start + value.translation.width))
            }.onEnded { _ in dragStartWidth = nil })
    }

    private func tab(from items: [String]) -> BrowserTab? {
        guard let raw = items.first, let id = UUID(uuidString: raw) else { return nil }
        return workspace.tabs.first { $0.id == id }
    }
}

/// Eén tab als rij in de zijbalk.
struct SidebarTabRow: View {
    @ObservedObject var tab: BrowserTab
    @ObservedObject var session: WebSession
    let selected: Bool
    var compact = false
    var accent: Color?
    let close: () -> Void
    /// V22: naar deze tab wisselen (voor het geluid-icoontje).
    var select: (() -> Void)? = nil
    @State private var hovering = false
    @Environment(\.joeToepTheme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if session.isLoading && !session.isPlaying { ProgressView().controlSize(.mini) }
                else if TabAudioIcon.isActionable(tab, session) {
                    Button { TabAudioIcon.perform(tab, session, select: { select?() }) } label: {
                        Image(systemName: TabAudioIcon.symbol(tab, session, hovering: hovering, base: icon))
                            .themedIcon(theme, size: 12, active: session.isPlaying).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
                else { Image(systemName: icon).themedIcon(theme, size: 12, active: session.isPlaying) }
            }
            .frame(width: 18)
            Text(tab.title).font(.callout.weight(selected ? .semibold : .regular)).lineLimit(1)
                .foregroundStyle(selected ? theme.foreground : theme.foreground.opacity(0.85))
            Spacer(minLength: 0)
            if session.isPlaying {
                Button { session.remoteToggle() } label: { Image(systemName: "pause.fill").font(.caption2) }
                    .buttonStyle(.plain).foregroundStyle(theme.accent).help("Pause")
            }
            if hovering || selected {
                Button(action: close) { Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).frame(width: 18, height: 18) }
                    .buttonStyle(.plain).foregroundStyle(theme.secondary).accessibilityLabel("Close tab")
            }
        }
        .padding(.horizontal, 8)
        .frame(height: compact ? 28 : 34)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(selected ? (accent ?? theme.foreground).opacity(selected ? 0.16 : 0) : (hovering ? theme.foreground.opacity(0.06) : .clear)))
        .contentShape(Rectangle())
        #if os(macOS)
        .onHover { hovering = $0 }
        #endif
        .help(tab.fullTitle)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
    private var icon: String {
        if session.isInPictureInPicture { return "pip" }
        if session.isPlaying { return "speaker.wave.2" }
        if tab.isPrivate { return "eyeglasses" }
        return NavigationPolicy.isPlaybackPage(tab.currentURL) ? "play.rectangle" : "globe"
    }
}

/// Vastgezette tab als tegel (bovenaan de zijbalk).
struct PinnedTile: View {
    @ObservedObject var tab: BrowserTab
    @ObservedObject var session: WebSession
    let selected: Bool
    @Environment(\.joeToepTheme) private var theme
    var body: some View {
        VStack(spacing: 2) {
            ZStack(alignment: .topTrailing) {
                Text(String((tab.currentURL?.host?.replacingOccurrences(of: "www.", with: "") ?? tab.title).prefix(1)).uppercased())
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(selected ? Color.white : theme.foreground)
                    .frame(maxWidth: .infinity).frame(height: 38)
                if session.isPlaying { Circle().fill(theme.accent).frame(width: 7, height: 7).padding(4) }
            }
        }
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(selected ? theme.accent : theme.foreground.opacity(0.08)))
        .help(tab.fullTitle)
        .accessibilityLabel(tab.fullTitle)
    }
}

/// Kleine Now Playing onderaan de zijbalk: wat er speelt (hier of Spotify), met play/pauze.
struct SidebarNowPlaying: View {
    @ObservedObject var workspace: BrowserWorkspace
    @ObservedObject private var spotify = SpotifyController.shared
    @Environment(\.joeToepTheme) private var theme
    var body: some View {
        let playingTab = workspace.tabs.first { $0.session.isPlaying }
        if playingTab != nil || spotify.current?.hasTrack == true {
            HStack(spacing: 8) {
                Image(systemName: playingTab != nil ? "play.rectangle.fill" : "music.note").foregroundStyle(theme.accent)
                VStack(alignment: .leading, spacing: 0) {
                    Text(playingTab?.title ?? spotify.current?.track ?? "").font(.caption.weight(.semibold)).lineLimit(1)
                    Text(playingTab != nil ? "Playing" : (spotify.current?.artist ?? "")).font(.caption2).foregroundStyle(theme.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                Button {
                    if let playingTab { playingTab.session.remoteToggle() } else { spotify.perform(.playPause) }
                } label: {
                    Image(systemName: (playingTab != nil || spotify.current?.playing == true) ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.plain)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(theme.foreground.opacity(0.06)))
            .padding(.horizontal, 8)
            .onTapGesture { if let playingTab { workspace.select(playingTab) } }
        }
    }
}
