// Dit bestand tekent het "Bibliotheek"-scherm: bladwijzers, geschiedenis en
// recent gesloten tabbladen, plus (helemaal onderaan) de "zoeken op pagina"-balk.
import SwiftUI

/// V15: bookmarks, history and recently closed tabs.
// Het hoofdscherm van de bibliotheek.
struct LibraryView: View {
    // Deze twee objecten bestaan al elders (de bladwijzers/geschiedenis-data
    // en de tab-workspace) en worden hier alleen gevolgd voor updates.
    @ObservedObject var library: BrowserLibrary
    @ObservedObject var workspace: BrowserWorkspace
    // @Environment(\.dismiss) geeft een functie om dit scherm (dat als sheet/
    // modaal venster getoond wordt) weer te sluiten.
    @Environment(\.dismiss) private var dismiss
    @Environment(\.joeToepTheme) private var theme
    // @State is voor waarden die BIJ dit scherm horen en veranderen tijdens
    // gebruik (bijv. welk tabblad/sectie gekozen is); SwiftUI tekent het
    // scherm automatisch opnieuw als zo'n waarde wijzigt.
    @State private var section = Section.bookmarks
    @State private var query = ""
    @State private var confirmClear = false
    // Een eigen enum (opsomming van vaste keuzes) voor de drie secties
    // bovenin: Bladwijzers, Geschiedenis, Recent gesloten.
    enum Section: String, CaseIterable, Identifiable {
        case bookmarks = "Bookmarks", history = "History", closed = "Recently closed"
        // Identifiable vereist een "id"; hier gebruiken we gewoon de tekstwaarde zelf.
        var id: String { rawValue }
    }

    // Bepaalt of een item overeenkomt met de ingetypte zoekterm (query).
    // Is er niks getypt, dan telt alles als een match.
    private func matches(_ item: LibraryItem) -> Bool {
        query.isEmpty || item.title.localizedCaseInsensitiveContains(query) || item.url.absoluteString.localizedCaseInsensitiveContains(query)
    }

    var body: some View {
        // NavigationStack geeft dit scherm een navigatiebalk bovenin (met
        // titel en knoppen) en maakt het mogelijk om dieper te navigeren.
        NavigationStack {
            // List toont een scrollbare lijst met rijen, zoals in Instellingen-apps.
            List {
                // Picker is de segmented control bovenin om van sectie te wisselen.
                // $section is een "Binding": de Picker mag section aanpassen.
                Picker("Section", selection: $section) {
                    ForEach(Section.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .listRowBackground(Color.clear)
                // switch kiest precies één van de gevallen hieronder, op basis
                // van de huidige waarde van "section".
                switch section {
                case .bookmarks:
                    // "let items = ..." maakt een tijdelijke, lokale lijst met
                    // alleen de bladwijzers die bij de zoekterm passen.
                    let items = library.bookmarks.filter(matches)
                    if items.isEmpty { empty("No bookmarks yet", "Use ⋯ › Add Bookmark (⌘D) on any page.") }
                    // ForEach herhaalt "row(...)" voor elk item in de lijst.
                    ForEach(items) { item in row(item) { library.removeBookmark(item) } }
                case .history:
                    let items = library.history.filter(matches)
                    if items.isEmpty { empty("No history", "Pages you visit appear here (not in private tabs).") }
                    // Geschiedenis wordt eerst per dag gegroepeerd (zie
                    // groupedHistory hieronder), en per dag als eigen sectie
                    // met kopje getoond.
                    ForEach(groupedHistory(items), id: \.0) { day, entries in
                        SwiftUI.Section(day) {
                            ForEach(entries) { item in row(item) { library.removeHistory(item) } }
                        }
                    }
                case .closed:
                    if workspace.closedTabs.isEmpty { empty("No recently closed tabs", "Closed tabs can be reopened with ⌘⇧T.") }
                    // enumerated() geeft naast elk item ook zijn index (0, 1, 2, ...)
                    // mee, zodat we weten of het het meest recent gesloten tabblad is.
                    ForEach(Array(workspace.closedTabs.enumerated()), id: \.element.id) { index, saved in
                        Button {
                            // Het eerst gesloten (index 0) tabblad heropenen we
                            // via de speciale "reopen"-functie; anders openen
                            // we gewoon de URL opnieuw als nieuw tabblad.
                            if index == 0 { workspace.reopenClosedTab() }
                            else if let url = saved.url { workspace.addTab(url: url) }
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                // "??" is de "nil-coalescing operator": gebruik
                                // de linkerkant als die een waarde heeft,
                                // anders de rechterkant als terugvaloptie.
                                Text(saved.title ?? TabTitleSummarizer.fallbackTitle(for: saved.url)).lineLimit(1)
                                Text(saved.url?.absoluteString ?? "").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                    }
                }
            }
            // .searchable voegt automatisch een zoekbalk toe die aan $query gekoppeld is.
            .searchable(text: $query, prompt: "Search \(section.rawValue.lowercased())")
            .navigationTitle("Library")
            // .toolbar voegt knoppen toe aan de navigatiebalk.
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                if section == .history && !library.history.isEmpty {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Clear…", role: .destructive) { confirmClear = true }
                    }
                }
            }
            // .confirmationDialog toont een keuzemenu (actiesheet) zodra
            // confirmClear op true wordt gezet, om per ongeluk wissen te voorkomen.
            .confirmationDialog("Clear browsing history?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Last hour", role: .destructive) { library.clearHistory(since: Date().addingTimeInterval(-3600)) }
                Button("Today", role: .destructive) { library.clearHistory(since: Calendar.current.startOfDay(for: Date())) }
                Button("All history", role: .destructive) { library.clearHistory() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // Zet een platte lijst met geschiedenis-items om in groepen per dag,
    // bijvoorbeeld [("Vandaag", [item1, item2]), ("Gisteren", [item3])].
    private func groupedHistory(_ items: [LibraryItem]) -> [(String, [LibraryItem])] {
        // DateFormatter zet een Date om naar leesbare tekst, bijvoorbeeld "Today".
        let formatter = DateFormatter(); formatter.dateStyle = .full; formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = true
        var result: [(String, [LibraryItem])] = []
        // We bekijken hooguit de eerste 600 items, om de lijst niet te traag te maken.
        for item in items.prefix(600) {
            let day = formatter.string(from: item.date)
            // Hoort dit item bij dezelfde dag als de laatst toegevoegde groep?
            // Voeg het dan daaraan toe, anders begin een nieuwe groep.
            if result.last?.0 == day { result[result.count - 1].1.append(item) } else { result.append((day, [item])) }
        }
        return result
    }

    // Bouwt één rij in de lijst (voor een bladwijzer of geschiedenis-item),
    // met een "delete"-functie die wordt meegegeven door wie deze rij gebruikt.
    // "@escaping" betekent dat deze functie later (na het teruggeven van
    // row zelf) nog aangeroepen mag worden, bijvoorbeeld bij een swipe.
    private func row(_ item: LibraryItem, delete: @escaping () -> Void) -> some View {
        Button {
            // Bij een tik op de rij: laad de URL in het huidige tabblad en
            // sluit de bibliotheek.
            workspace.selected.session.load(item.url); dismiss()
        } label: {
            HStack(spacing: 10) {
                // Toon een afspeel-icoon voor video-pagina's, anders een globe-icoon.
                Image(systemName: NavigationPolicy.isPlaybackPage(item.url) ? "play.rectangle" : "globe")
                    .foregroundStyle(theme.accent).frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).lineLimit(1)
                    Text(item.url.host ?? item.url.absoluteString).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                // Spacer duwt de tekst ervoor naar links en de tijd erna naar rechts.
                Spacer()
                Text(item.date, style: .time).font(.caption2).foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // .contextMenu is het menu dat verschijnt bij lang indrukken/rechtsklikken.
        .contextMenu {
            Button { workspace.addTab(url: item.url); dismiss() } label: { Label("Open in New Tab", systemImage: "plus.square") }
            Button { workspace.addTab(url: item.url, activate: false) } label: { Label("Open in Background Tab", systemImage: "square.on.square") }
            Button { Clipboard.copy(item.url) } label: { Label("Copy Link", systemImage: "link") }
            Button(role: .destructive, action: delete) { Label("Delete", systemImage: "trash") }
        }
        // .swipeActions voegt de veeg-om-te-verwijderen-knop toe (vooral op iOS).
        .swipeActions { Button(role: .destructive, action: delete) { Label("Delete", systemImage: "trash") } }
    }

    // Een simpel "leeg" bericht (titel + uitleg) voor als een sectie geen items heeft.
    private func empty(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 12)
    }
}

/// V16: Chrome-style find on page (⌘F) on every platform. Typing searches immediately, Enter
/// jumps to the next match (⇧Enter previous), all matches are highlighted.
// De kleine zwevende balk die verschijnt als je op een pagina wilt zoeken (⌘F).
struct FindBar: View {
    @ObservedObject var session: WebSession
    // @Binding is een "doorgeefluik" naar een @State-waarde van een ander
    // scherm: als deze view "visible" aanpast, verandert het ook bij de
    // aanroeper (en andersom).
    @Binding var visible: Bool
    @State private var text = ""
    @State private var state = WebSession.FindState()
    // Een Task is een stukje asynchrone (op de achtergrond lopende) code; we
    // bewaren hem hier zodat we een vorige zoekopdracht kunnen annuleren.
    @State private var searchTask: Task<Void, Never>?
    // @FocusState houdt bij of het tekstveld actief geselecteerd is (met
    // cursor/klavier), zodat we het programmatisch kunnen focussen.
    @FocusState private var focused: Bool
    @Environment(\.joeToepTheme) private var theme
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(theme.secondary)
            // TextField is het invoerveld waar je de zoekterm typt.
            TextField("Find on page", text: $text)
                .textFieldStyle(.plain).frame(minWidth: 140, maxWidth: 260).focused($focused)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never).submitLabel(.next)
                #endif
                // Bij op Enter drukken: spring naar het volgende resultaat.
                .onSubmit { session.findNext { state = $0 }; focused = true }
                // .onChange draait telkens als "text" verandert (dus bij elke
                // toetsaanslag); we plannen dan een nieuwe zoekopdracht in.
                .onChange(of: text) { _, value in schedule(value) }
                #if os(macOS)
                .onExitCommand { close() }
                #endif
                .accessibilityIdentifier("find.field")
            // Toont "3/12" (huidige/aantal resultaten) of "No results".
            Text(text.isEmpty ? "" : (state.count == 0 ? "No results" : "\(state.index)/\(state.count)"))
                .font(.caption.monospacedDigit()).foregroundStyle(state.count == 0 && !text.isEmpty ? .red : theme.secondary)
                .frame(minWidth: 54)
            Button { session.findPrevious { state = $0 } } label: { Image(systemName: "chevron.up") }
                .buttonStyle(.plain).disabled(state.count == 0)
                .keyboardShortcut("g", modifiers: [.command, .shift])
            Button { session.findNext { state = $0 } } label: { Image(systemName: "chevron.down") }
                .buttonStyle(.plain).disabled(state.count == 0)
                .keyboardShortcut("g", modifiers: .command)
            // Een onzichtbare knop (opacity 0, breedte 0) die alleen bestaat
            // om Shift+Enter als sneltoets voor "vorige" te laten werken.
            Button { session.findPrevious { state = $0 } } label: { EmptyView() }
                .keyboardShortcut(.return, modifiers: .shift).frame(width: 0).opacity(0)
            Button { close() } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(theme.secondary) }
                .buttonStyle(.plain).keyboardShortcut(.cancelAction).accessibilityLabel("Close find")
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        // .background met .regularMaterial geeft een vervaagd/glazig effect,
        // in de vorm van een pilvormige "Capsule".
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        .padding(.horizontal, 12)
        // .onAppear draait zodra deze balk in beeld komt; we wachten heel
        // even (via de hoofdwachtrij) voordat we het tekstveld focussen.
        .onAppear { DispatchQueue.main.async { focused = true } }
    }
    // Plant een nieuwe zoekopdracht in, met een kleine vertraging ("debounce")
    // zodat we niet bij elke toetsaanslag meteen de hele pagina doorzoeken.
    private func schedule(_ value: String) {
        // Annuleer een eventuele nog lopende zoekopdracht van hiervoor.
        searchTask?.cancel()
        // Task { @MainActor in ... } start nieuwe, asynchrone code die op de
        // hoofdthread (voor UI-updates) uitgevoerd wordt.
        searchTask = Task { @MainActor in
            // Wacht 120 milliseconden; typt de gebruiker intussen verder, dan
            // wordt deze taak hierboven al geannuleerd.
            try? await Task.sleep(for: .milliseconds(120))
            // "guard" stopt de functie meteen als de voorwaarde niet klopt.
            // Hier: stop als deze taak intussen is geannuleerd.
            guard !Task.isCancelled else { return }
            session.find(value) { state = $0 }
        }
    }
    // Verwijdert de gele markeringen op de pagina en verbergt de zoekbalk.
    private func close() { session.clearFindHighlights(); visible = false }
}
