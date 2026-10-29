// Dit bestand tekent de balk met tabbladen bovenaan (of onderaan) het scherm:
// de losse tab-"chips", de +-knop voor een nieuw tabblad, en de adresbalk die
// verschijnt zodra je op het huidige tabblad tikt.
import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// V15 tab strip. With few tabs they share the full width up to the + button (so long titles are
/// readable); with many they shrink to a minimum width and the strip scrolls. Tapping the
/// selected tab turns it into an address bar (type a URL or a search).
// De volledige tabbladenbalk.
struct TabBarView: View {
    @ObservedObject var workspace: BrowserWorkspace
    @ObservedObject var settings: AppSettings
    // Binding: "editing" (zit de adresbalk in bewerkmodus?) wordt eigenlijk
    // bijgehouden door de aanroeper; deze view mag hem wel aanpassen.
    @Binding var editing: Bool
    /// V21: Safari-achtige ene balk — knoppen links en rechts van de tabs (Mac/iPad).
    var leading: AnyView? = nil
    var trailing: AnyView? = nil
    /// V21: ruimte links voor de venster-knopjes (rood/geel/groen) als de balk helemaal bovenin staat.
    var leadingInset: CGFloat = 0
    @State private var address = ""
    @FocusState private var addressFocused: Bool
    // V22: live slepen (Mac).
    @State private var dragID: UUID?
    @State private var dragOffset: CGFloat = 0
    @State private var dragLift: CGFloat = 0
    @State private var dragConsumed: CGFloat = 0
    @Environment(\.joeToepTheme) private var theme
    @Environment(\.openWindow) private var openWindow
    // Op de Mac is er wat meer ruimte, dus mogen tabbladen iets breder minimaal zijn.
    /// V17.1: maximale tabbreedte zolang er minder dan 4 tabs zijn (Mac en iPad).
    private let fewTabsMaxWidth: CGFloat = 220
    /// iPhone? (daar blijven tabs de volle breedte gebruiken; het scherm is smal genoeg)
    private var isPhone: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }
    #if os(macOS)
    private let minimumTabWidth: CGFloat = 104
    #else
    private let minimumTabWidth: CGFloat = 92
    #endif

    var body: some View {
        // HStack zet de onderdelen (tabstrip/adresbalk en de +-knoppen) naast elkaar.
        HStack(spacing: 4) {
            if leadingInset > 0 { WindowDragArea().frame(width: leadingInset, height: theme.tabHeight + 4) }
            if let leading { leading.fixedSize() }
            // ZStack laat ons wisselen tussen twee views (adresbalk of
            // tabstrip) die elkaar overlappen tijdens de animatie.
            ZStack {
                if editing {
                    addressField
                        .transition(.asymmetric(insertion: .scale(scale: 0.96, anchor: .leading).combined(with: .opacity), removal: .opacity))
                } else {
                    strip.transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity)
            if let trailing { trailing.fixedSize() }
        }
        .frame(height: theme.tabHeight + 8)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background {
            if settings.visualizerInTabBar { SessionVisualizer(session: workspace.selected.session) }
        }
        // .animation zorgt dat wijzigingen aan "editing" vloeiend geanimeerd worden.
        .animation(theme.anim(.addressBar), value: editing)
        .onChange(of: editing) { _, now in
            if now {
                // Bij het starten van bewerken: vul de adresbalk met de
                // huidige URL van het tabblad, en geef het tekstveld focus.
                address = workspace.selected.currentURL?.absoluteString ?? ""
                DispatchQueue.main.async { addressFocused = true }
            }
        }
    }

    #if os(macOS)
    private func dragChanged(_ tab: BrowserTab, value: DragGesture.Value, stride: CGFloat) {
        if dragID != tab.id { dragID = tab.id; dragConsumed = 0 }
        var remaining = value.translation.width - dragConsumed
        // Voorbij de helft van de buurtab → een plek opschuiven (ook meerdere bij snel slepen).
        while abs(remaining) > stride * 0.5 {
            let step = remaining > 0 ? 1 : -1
            var moved = false
            withAnimation(Motion.quick(0.18)) { moved = workspace.stepTab(id: tab.id, by: step) }
            guard moved else { break }
            dragConsumed += CGFloat(step) * stride
            remaining = value.translation.width - dragConsumed
        }
        dragOffset = remaining
        dragLift = max(-4, min(4, value.translation.height * 0.15))   // voelt mee, maar blijft in de balk
    }
    private func dragEnded() {
        withAnimation(Motion.quick(0.2)) { dragOffset = 0; dragLift = 0; dragID = nil }
        dragConsumed = 0
        workspace.finishTabDrag()
    }
    #endif

    // De horizontale strook met alle tab-chips naast elkaar.
    private var strip: some View {
        GeometryReader { geometry in
            // Berekent hoe breed elk tabblad zou moeten zijn als ze allemaal
            // gelijk verdeeld worden over de beschikbare breedte.
            let count = CGFloat(max(workspace.tabs.count, 1))
            let spacing: CGFloat = 4
            // V19.2: ruimte voor de +-knop direct achter de tabs.
            let plusWidth: CGFloat = settings.showNewTabButton ? (showsWindowButton ? 64 : 32) + spacing : 0
            let room = geometry.size.width - plusWidth
            let natural = (room - spacing * (count - 1)) / count
            // Maar nooit smaller dan het minimum; anders scrollen we liever.
            // V17.1 (Mac en iPad): met 1–3 tabs worden tabs niet meer over de hele breedte
            // uitgerekt maar maximaal `fewTabsMaxWidth` breed; pas vanaf 4 tabs delen ze de ruimte.
            // V19.2: 1 tab ≈ de halve breedte, 2 tabs = samen de volle breedte, 3+ = kleiner (gelijk
            // verdeeld, nooit onder het minimum; daarna scrollen).
            let width = workspace.tabs.count == 1 ? max(room / 2, minimumTabWidth) : max(natural, minimumTabWidth)
            // ScrollViewReader geeft toegang tot "proxy", waarmee we
            // programmatisch naar een specifiek tabblad kunnen scrollen.
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: spacing) {
                        ForEach(workspace.tabs) { tab in
                            TabChip(tab: tab, session: tab.session, selected: workspace.selectedID == tab.id, width: width,
                                    select: { tapped(tab) }, close: { workspace.close(tab) })
                                .contextMenu { menu(for: tab) }
                                #if os(macOS)
                                // V22 (Mac): de héle tab beweegt mee met de muis en de andere tabs schuiven
                                // opzij. Heel vergevingsgezind: boven/onder de balk loslaten maakt niet uit —
                                // alleen de horizontale positie telt en hij snapt naar de dichtstbijzijnde plek.
                                .offset(x: dragID == tab.id ? dragOffset : 0, y: dragID == tab.id ? dragLift : 0)
                                .scaleEffect(dragID == tab.id ? 1.03 : 1)
                                .shadow(color: .black.opacity(dragID == tab.id ? 0.35 : 0), radius: 8, y: 3)
                                .zIndex(dragID == tab.id ? 10 : 0)
                                .simultaneousGesture(
                                    DragGesture(minimumDistance: 5, coordinateSpace: .global)
                                        .onChanged { value in dragChanged(tab, value: value, stride: width + spacing) }
                                        .onEnded { _ in dragEnded() }
                                )
                                #else
                                // V19.1: slepen om te herordenen (iPad en iPhone). Laat je een tab
                                // op een andere tab los, dan komt hij op die plek te staan.
                                .draggable(tab.id.uuidString) {
                                    Text(tab.title).font(.caption).padding(6)
                                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
                                }
                                .dropDestination(for: String.self) { items, _ in
                                    guard let raw = items.first, let id = UUID(uuidString: raw) else { return false }
                                    return workspace.moveTab(id: id, before: tab.id)
                                }
                                #endif
                                // .id() geeft deze view een uniek label, zodat
                                // scrollTo(id) hem later kan terugvinden.
                                .id(tab.id)
                                .transition(.asymmetric(insertion: .scale(scale: 0.5, anchor: .leading).combined(with: .opacity),
                                                        removal: .scale(scale: 0.6).combined(with: .opacity)))
                        }
                        // V21: + en "nieuw venster" vlak tegen de laatste tab aan (minimale ruimte).
                        if settings.showNewTabButton {
                            HStack(spacing: 0) {
                                newTabButton
                                if showsWindowButton { newWindowButton }
                            }
                            .padding(.leading, -spacing + 1)
                        }
                        // V19.2: sleep je een tab voorbij de laatste (op + of de lege ruimte), dan komt hij achteraan.
                        Color.clear.frame(maxWidth: .infinity, minHeight: theme.tabHeight)
                            .contentShape(Rectangle())
                            // V19.3/V21 (Mac): lege balk = venster verslepen; dubbelklik = maximaliseren
                            // (volgt je macOS-instelling: zoomen/vullen of minimaliseren).
                            #if os(macOS)
                            .overlay(WindowDragArea())
                            #else
                            .onTapGesture(count: 2) { WindowZoom.titleBarDoubleClick() }
                            #endif
                            .dropDestination(for: String.self) { items, _ in
                                guard let raw = items.first, let id = UUID(uuidString: raw) else { return false }
                                return workspace.moveTabToEnd(id: id)
                            }
                    }
                    .frame(minWidth: geometry.size.width, alignment: .leading)
                    .animation(theme.animation, value: workspace.tabs.map(\.id))
                    .animation(theme.animation, value: workspace.selectedID)
                }
                .scrollIndicators(.hidden)
                // Scrollen is alleen nodig/toegestaan als de natuurlijke
                // breedte kleiner is dan het minimum (dus als tabbladen niet
                // meer allemaal tegelijk passen).
                .scrollDisabled(natural >= minimumTabWidth)
                .onChange(of: workspace.selectedID) { _, id in
                    guard natural < minimumTabWidth else { return }
                    // Scrol automatisch (met animatie) naar het net
                    // geselecteerde tabblad, zodat het zichtbaar in beeld komt.
                    withAnimation(theme.animation) { proxy.scrollTo(id, anchor: .center) }
                }
            }
        }
        .frame(height: theme.tabHeight + 4)
    }

    /// V21: "nieuw venster" direct naast de + (Mac en iPad; iPhone heeft geen losse vensters).
    private var showsWindowButton: Bool {
        #if os(macOS)
        true
        #else
        UIDevice.current.userInterfaceIdiom == .pad
        #endif
    }
    private var newWindowButton: some View {
        Button { openWindow(id: "main") } label: {
            Image(systemName: "macwindow.badge.plus").themedIcon(theme, size: 13 * theme.density.scale)
                .frame(width: 32, height: theme.tabHeight + 4).contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityLabel("New window").accessibilityIdentifier("windows.new")
        .help("New window (⌘N)")
    }

    /// V19.2: de +-knop, direct achter de laatste tab. Ook een plek om een tab achteraan neer te zetten.
    private var newTabButton: some View {
        Button(action: workspace.requestNewTab) {
            Image(systemName: "plus").themedIcon(theme, size: 15 * theme.density.scale)
                .frame(width: 32, height: theme.tabHeight + 4).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { workspace.addTab() } label: { Label("New Tab", systemImage: "plus.square") }
            Button { workspace.addPrivateTab() } label: { Label("New Private Tab", systemImage: "eyeglasses") }
            Button { workspace.reopenClosedTab() } label: { Label("Reopen Closed Tab", systemImage: "arrow.uturn.backward") }
                .disabled(workspace.closedTabs.isEmpty)
        }
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first, let id = UUID(uuidString: raw) else { return false }
            return workspace.moveTabToEnd(id: id)
        }
        .accessibilityLabel("New tab").accessibilityIdentifier("tabs.new")
        .help("New tab (⌘T) · right-click for a private tab")
    }

    // De adresbalk die verschijnt zodra je op het geselecteerde tabblad tikt.
    private var addressField: some View {
        HStack(spacing: 8) {
            Image(systemName: workspace.selected.isPrivate ? "eyeglasses" : "magnifyingglass")
                .foregroundStyle(theme.secondary)
            TextField("Search \(settings.searchEngine.title) or enter a website", text: $address)
                .textFieldStyle(.plain)
                .font(theme.tabFont.weight(.medium))
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
                .buttonStyle(.plain).foregroundStyle(theme.accent).font(theme.tabFont.weight(.semibold))
                .accessibilityIdentifier("tabs.address.cancel")
        }
        .padding(.horizontal, 10)
        .frame(height: theme.tabHeight + 2)
        .background(theme.style.surface, in: RoundedRectangle(cornerRadius: theme.tabCornerRadius, style: .continuous))
        .onChange(of: addressFocused) { _, focused in
            if !focused { DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { if !addressFocused { editing = false } } }
        }
    }

    // Wordt aangeroepen als de gebruiker in de adresbalk op Enter/Go drukt.
    private func submit() {
        let text = address
        editing = false
        workspace.selected.session.loadAddress(text)
    }

    // Bepaalt wat een tik op een tabblad doet: is het al geselecteerd, ga dan
    // naar bewerkmodus (adresbalk); is het nog niet geselecteerd, selecteer het gewoon.
    private func tapped(_ tab: BrowserTab) {
        // V22: een klik op het geluid-icoontje is geen klik op de tab zelf.
        // (Eén beurt later beslissen: de knop en de tab-klik komen in willekeurige volgorde binnen.)
        if TabAudioIcon.selecting { workspace.select(tab); return }
        let wasSelected = workspace.selectedID == tab.id
        DispatchQueue.main.async {
            if Date().timeIntervalSince(TabAudioIcon.lastAction) < 0.4 { return }
            if wasSelected {
                if CommandBarPrefs.overlayForAddress { workspace.requestEditAddress() } else { editing = true }
            } else { workspace.select(tab) }
        }
    }

    // @ViewBuilder vertelt Swift dat deze functie meerdere views achter
    // elkaar mag "opbouwen" (zoals in een normale SwiftUI-body), voor het
    // rechtermuisknop-menu van een tabblad.
    @ViewBuilder
    private func menu(for tab: BrowserTab) -> some View {
        Button { workspace.togglePin(tab) } label: {
            Label(tab.pinned ? "Unpin Tab" : "Pin Tab", systemImage: tab.pinned ? "pin.slash" : "pin")
        }
        Button { workspace.select(tab); editing = true } label: { Label("Edit Address…", systemImage: "character.cursor.ibeam") }
        Button { tab.session.reload() } label: { Label("Reload", systemImage: "arrow.clockwise") }
        Button { workspace.duplicate(tab) } label: { Label("Duplicate Tab", systemImage: "plus.square.on.square") }
        if !workspace.otherDevices.isEmpty {
            Menu("Continue on…") {
                ForEach(workspace.otherDevices, id: \.id) { d in
                    Button(d.name) { workspace.continuePlayback(of: tab, on: d.id) }
                }
            }
        }
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
// Eén los tabblad-"chipje" in de balk.
struct TabChip: View {
    @ObservedObject var tab: BrowserTab
    @ObservedObject var session: WebSession
    let selected: Bool
    let width: CGFloat
    // Deze twee zijn functies die worden meegegeven door wie TabChip gebruikt
    // (dus geen eigen logica hier, alleen "roep dit aan als er getikt wordt").
    let select: () -> Void
    let close: () -> Void
    // Houdt bij of de muis erboven zweeft (alleen relevant op de Mac).
    @State private var hovering = false
    @Environment(\.joeToepTheme) private var theme

    // Berekent of het kruisje om te sluiten getoond moet worden, afhankelijk
    // van de gekozen instelling (altijd/alleen geselecteerd/bij hover/nooit).
    private var showsClose: Bool {
        guard !tab.pinned else { return false }
        switch theme.tabClose {
        case .always: return true
        case .selected: return selected
        case .hover: return selected || hovering
        case .never: return false
        }
    }
    // Kiest welk icoontje getoond wordt vóór de titel, op basis van de status
    // van het tabblad (speelt af, vastgezet, privé, site-type).
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
                    // Terwijl de pagina laadt (en niet al aan het afspelen is)
                    // tonen we een draaiend laad-icoontje in plaats van het gewone icoon.
                    if session.isLoading && !session.isPlaying {
                        ProgressView().controlSize(.mini)
                    } else if TabAudioIcon.isActionable(tab, session) {
                        // V22: klik op het icoon = pauzeren / daar afspelen.
                        Button { TabAudioIcon.perform(tab, session, select: select) } label: {
                            Image(systemName: TabAudioIcon.symbol(tab, session, hovering: hovering, base: iconName))
                                .themedIcon(theme, size: 11 * theme.density.scale, active: session.isPlaying || tab.pinned)
                                .frame(width: 18, height: 18).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(session.isPlaying ? "Pause" : "Play in this tab")
                        .accessibilityLabel(session.isPlaying ? "Pause this tab" : "Play this tab")
                    } else {
                        Image(systemName: iconName)
                            .themedIcon(theme, size: 11 * theme.density.scale, active: session.isPlaying || tab.pinned)
                    }
                }
                .frame(width: 16)
            }
            Text(tab.title)
                .font(theme.tabFont.weight(selected ? .semibold : .regular))
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
        // .contentShape(Rectangle()) zorgt dat de HELE rechthoek tikbaar is,
        // ook de lege ruimtes, niet alleen de zichtbare tekst/iconen.
        .contentShape(Rectangle())
        .onTapGesture(perform: select)
        #if os(macOS)
        .onHover { hovering = $0 }
        #endif
        .middleClick(close)   // V16: middle mouse button closes the tab (Mac)
        .help(tab.fullTitle)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel(tab.fullTitle)
        .accessibilityIdentifier("tab.select.\(tab.id)")
        .animation(theme.animation, value: showsClose)
    }

    // De achtergrondvorm/-kleur van het tabblad: verschilt per thema-stijl
    // (onderstreping versus gevulde vorm) en of het geselecteerd/privé is.
    @ViewBuilder
    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: theme.tabCornerRadius, style: .continuous)
        if theme.tabShape == .underline {
            shape.fill(hovering ? theme.style.hover : .clear)
        } else if selected && GlassPrefs.enabled && !tab.isPrivate {
            // V21: Liquid Glass voor de actieve tab (strak, minimaal).
            Color.clear.joeToepGlass(in: shape)
        } else if selected {
            shape.fill(tab.isPrivate ? Color.purple.opacity(0.35) : theme.style.surface)
                .overlay(shape.stroke(theme.accent.opacity(theme.rendering == .monochrome ? 0 : 0.5), lineWidth: 1))
        } else {
            shape.fill(hovering ? theme.style.hover : (tab.isPrivate ? Color.purple.opacity(0.15) : .clear))
        }
    }
}

// Een klein hulpmiddel (enum met alleen "static" functies, dus geen eigen
// data) om een URL naar het systeem-klembord te kopiëren.
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


/// V19.3 — Dubbelklikken op de balk bovenin, zoals bij elke Mac-app.
enum WindowZoom {
    static func titleBarDoubleClick() {
        #if os(macOS)
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
        let action = UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") ?? "Maximize"
        switch action {
        case "Minimize": window.miniaturize(nil)
        case "None": break
        default: window.zoom(nil)          // "Maximize"/"Fill": venster zo groot mogelijk
        }
        #endif
    }
}


/// V21 — Lege plek in de balk: slepen verplaatst het venster, dubbelklik maximaliseert (Mac).
struct WindowDragArea: View {
    var body: some View {
        #if os(macOS)
        DragRepresentable()
        #else
        Color.clear
        #endif
    }
    #if os(macOS)
    private struct DragRepresentable: NSViewRepresentable {
        func makeNSView(context: Context) -> NSView { DragView() }
        func updateNSView(_ nsView: NSView, context: Context) {}
    }
    private final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
        override func mouseDown(with event: NSEvent) {
            if event.clickCount == 2 { WindowZoom.titleBarDoubleClick(); return }
            window?.performDrag(with: event)
        }
    }
    #endif
}
