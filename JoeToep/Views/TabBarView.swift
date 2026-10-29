import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// V15 tab strip. With few tabs they share the full width up to the + button (so long titles are
/// readable); with many they shrink to a minimum width and the strip scrolls. Tapping the
/// selected tab turns it into an address bar (type a URL or a search).
struct TabBarView: View {
    @ObservedObject var workspace: BrowserWorkspace
    @ObservedObject var settings: AppSettings
    @Binding var editing: Bool
    @State private var address = ""
    @FocusState private var addressFocused: Bool
    @Environment(\.joeToepTheme) private var theme
    @Environment(\.openWindow) private var openWindow
    #if os(macOS)
    private let minimumTabWidth: CGFloat = 104
    #else
    private let minimumTabWidth: CGFloat = 92
    #endif

    var body: some View {
        HStack(spacing: 4) {
            ZStack {
                if editing {
                    addressField
                        .transition(.asymmetric(insertion: .scale(scale: 0.96, anchor: .leading).combined(with: .opacity), removal: .opacity))
                } else {
                    strip.transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity)
            if !editing {
                Button(action: workspace.addTab) {
                    Image(systemName: "plus").themedIcon(theme, size: 15 * theme.density.scale)
                        .frame(width: 36, height: theme.tabHeight + 4).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button { workspace.addTab() } label: { Label("New Tab", systemImage: "plus.square") }
                    Button { workspace.addPrivateTab() } label: { Label("New Private Tab", systemImage: "eyeglasses") }
                    Button { workspace.reopenClosedTab() } label: { Label("Reopen Closed Tab", systemImage: "arrow.uturn.backward") }
                        .disabled(workspace.closedTabs.isEmpty)
                }
                .accessibilityLabel("New tab").accessibilityIdentifier("tabs.new")
                .help("New tab (⌘T) · right-click for a private tab")
                #if os(macOS)
                Button { openWindow(id: "main") } label: {
                    Image(systemName: "macwindow.badge.plus").themedIcon(theme, size: 14 * theme.density.scale)
                        .frame(width: 34, height: theme.tabHeight + 4).contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityLabel("New window").accessibilityIdentifier("windows.new")
                #else
                if UIDevice.current.userInterfaceIdiom == .pad {
                    Button { openWindow(id: "main") } label: {
                        Image(systemName: "rectangle.badge.plus").themedIcon(theme, size: 14 * theme.density.scale)
                            .frame(width: 34, height: theme.tabHeight + 4).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).accessibilityLabel("New window")
                }
                #endif
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .animation(theme.animation, value: editing)
        .onChange(of: editing) { _, now in
            if now {
                address = workspace.selected.currentURL?.absoluteString ?? ""
                DispatchQueue.main.async { addressFocused = true }
            }
        }
    }

    private var strip: some View {
        GeometryReader { geometry in
            let count = CGFloat(max(workspace.tabs.count, 1))
            let spacing: CGFloat = 4
            let natural = (geometry.size.width - spacing * (count - 1)) / count
            let width = max(natural, minimumTabWidth)
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: spacing) {
                        ForEach(workspace.tabs) { tab in
                            TabChip(tab: tab, session: tab.session, selected: workspace.selectedID == tab.id, width: width,
                                    select: { tapped(tab) }, close: { workspace.close(tab) })
                                .contextMenu { menu(for: tab) }
                                .id(tab.id)
                                .transition(.asymmetric(insertion: .scale(scale: 0.5, anchor: .leading).combined(with: .opacity),
                                                        removal: .scale(scale: 0.6).combined(with: .opacity)))
                        }
                    }
                    .frame(minWidth: geometry.size.width, alignment: .leading)
                    .animation(theme.animation, value: workspace.tabs.map(\.id))
                    .animation(theme.animation, value: workspace.selectedID)
                }
                .scrollIndicators(.hidden)
                .scrollDisabled(natural >= minimumTabWidth)
                .onChange(of: workspace.selectedID) { _, id in
                    guard natural < minimumTabWidth else { return }
                    withAnimation(theme.animation) { proxy.scrollTo(id, anchor: .center) }
                }
            }
        }
        .frame(height: theme.tabHeight + 4)
    }

    private var addressField: some View {
        HStack(spacing: 8) {
            Image(systemName: workspace.selected.isPrivate ? "eyeglasses" : "magnifyingglass")
                .foregroundStyle(theme.secondary)
            TextField("Search \(settings.searchEngine.title) or enter a website", text: $address)
                .textFieldStyle(.plain)
                .font(theme.tabText.font.weight(.medium))
                .foregroundStyle(theme.foreground)
                .focused($addressFocused)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.webSearch)
                .submitLabel(.go)
                #endif
                .onSubmit(submit)
                #if os(macOS)
                .onExitCommand { editing = false }
                #endif
                .accessibilityIdentifier("tabs.address")
            if !address.isEmpty {
                Button { address = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(theme.secondary) }
                    .buttonStyle(.plain).accessibilityLabel("Clear")
            }
            Button("Cancel") { editing = false }
                .buttonStyle(.plain).foregroundStyle(theme.accent).font(theme.tabText.font.weight(.semibold))
                .accessibilityIdentifier("tabs.address.cancel")
        }
        .padding(.horizontal, 10)
        .frame(height: theme.tabHeight + 2)
        .background(theme.style.surface, in: RoundedRectangle(cornerRadius: theme.tabCornerRadius, style: .continuous))
        .onChange(of: addressFocused) { _, focused in
            if !focused { DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { if !addressFocused { editing = false } } }
        }
    }

    private func submit() {
        let text = address
        editing = false
        workspace.selected.session.loadAddress(text)
    }

    private func tapped(_ tab: BrowserTab) {
        if workspace.selectedID == tab.id { editing = true } else { workspace.select(tab) }
    }

    @ViewBuilder
    private func menu(for tab: BrowserTab) -> some View {
        Button { workspace.togglePin(tab) } label: {
            Label(tab.pinned ? "Unpin Tab" : "Pin Tab", systemImage: tab.pinned ? "pin.slash" : "pin")
        }
        Button { workspace.select(tab); editing = true } label: { Label("Edit Address…", systemImage: "character.cursor.ibeam") }
        Button { tab.session.reload() } label: { Label("Reload", systemImage: "arrow.clockwise") }
        Button { workspace.duplicate(tab) } label: { Label("Duplicate Tab", systemImage: "plus.square.on.square") }
        if let url = tab.currentURL {
            Button { Clipboard.copy(url) } label: { Label("Copy Link", systemImage: "link") }
            ShareLink(item: url) { Label("Share…", systemImage: "square.and.arrow.up") }
        }
        Divider()
        Button { workspace.move(tab, by: -1) } label: { Label("Move Left", systemImage: "arrow.left") }
        Button { workspace.move(tab, by: 1) } label: { Label("Move Right", systemImage: "arrow.right") }
        Divider()
        Button(role: .destructive) { workspace.close(tab) } label: { Label("Close Tab", systemImage: "xmark") }
        Button { workspace.closeOthers(tab) } label: { Label("Close Other Tabs", systemImage: "xmark.square") }
            .disabled(workspace.tabs.count < 2)
        Button { workspace.closeToTheRight(of: tab) } label: { Label("Close Tabs to the Right", systemImage: "arrow.right.to.line") }
            .disabled(workspace.tabs.last?.id == tab.id)
    }
}

/// One tab: icon (playing / pinned / private / site), title and a close button.
struct TabChip: View {
    @ObservedObject var tab: BrowserTab
    @ObservedObject var session: WebSession
    let selected: Bool
    let width: CGFloat
    let select: () -> Void
    let close: () -> Void
    @State private var hovering = false
    @Environment(\.joeToepTheme) private var theme

    private var showsClose: Bool {
        guard !tab.pinned else { return false }
        switch theme.tabClose {
        case .always: return true
        case .selected: return selected
        case .hover: return selected || hovering
        case .never: return false
        }
    }
    private var iconName: String {
        if session.isInPictureInPicture { return "pip" }
        if session.isPlaying { return "speaker.wave.2" }
        if tab.pinned { return "pin" }
        if tab.isPrivate { return "eyeglasses" }
        if let host = tab.currentURL?.host?.lowercased(), !NavigationPolicy.isYouTubeHost(host) { return "globe" }
        return NavigationPolicy.isPlaybackPage(tab.currentURL) ? "play.rectangle" : "house"
    }

    var body: some View {
        HStack(spacing: 6) {
            if theme.showTabIcons {
                ZStack {
                    if session.isLoading && !session.isPlaying {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: iconName)
                            .themedIcon(theme, size: 11 * theme.density.scale, active: session.isPlaying || tab.pinned)
                    }
                }
                .frame(width: 16)
            }
            Text(tab.title)
                .font(theme.tabText.font.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? theme.foreground : theme.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: theme.showTabIcons ? .leading : .center)
                .contentTransition(.opacity)
                .animation(theme.animation, value: tab.title)
            if showsClose {
                Button(action: close) {
                    Image(systemName: "xmark").font(.system(size: 9 * theme.density.scale, weight: .bold))
                        .foregroundStyle(theme.secondary)
                        .frame(width: 18, height: 18)
                        .background(hovering ? theme.style.hover : .clear, in: Circle())
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close tab").accessibilityIdentifier("tab.close")
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 10)
        .frame(width: width, height: theme.tabHeight)
        .background { background }
        .overlay(alignment: .bottom) {
            if theme.tabShape == .underline && selected {
                Capsule().fill(theme.accent).frame(height: 2.5).padding(.horizontal, 8)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: select)
        #if os(macOS)
        .onHover { hovering = $0 }
        #endif
        .help(tab.fullTitle)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel(tab.fullTitle)
        .accessibilityIdentifier("tab.select.\(tab.id)")
        .animation(theme.animation, value: showsClose)
    }

    @ViewBuilder
    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: theme.tabCornerRadius, style: .continuous)
        if theme.tabShape == .underline {
            shape.fill(hovering ? theme.style.hover : .clear)
        } else if selected {
            shape.fill(tab.isPrivate ? Color.purple.opacity(0.35) : theme.style.surface)
                .overlay(shape.stroke(theme.accent.opacity(theme.rendering == .monochrome ? 0 : 0.5), lineWidth: 1))
        } else {
            shape.fill(hovering ? theme.style.hover : (tab.isPrivate ? Color.purple.opacity(0.15) : .clear))
        }
    }
}

enum Clipboard {
    static func copy(_ url: URL) {
        #if os(iOS)
        UIPasteboard.general.url = url
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
        #endif
    }
}
