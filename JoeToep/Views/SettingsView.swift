// Dit bestand tekent het instellingenscherm van de app: het hoofdscherm met
// de lijst van instellingencategorieën, en daaronder alle losse
// subschermen (Uiterlijk, Tabs, Afspelen, Advertenties, enzovoort).
import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// V15 settings: grouped pages with every option adjustable.
// "struct SettingsView: View" maakt een nieuw SwiftUI-scherm. Een struct is
// hier een "bouwplan" voor een stukje interface; het volgt het View-protocol,
// wat wil zeggen dat het verplicht een "var body" heeft die vertelt hoe het
// eruitziet.
struct SettingsView: View {
    // @ObservedObject verbindt dit scherm met een bestaand object (settings,
    // session) dat @Published properties heeft: verandert daar iets, dan
    // tekent dit scherm zichzelf opnieuw.
    @ObservedObject var settings: AppSettings
    @ObservedObject var session: WebSession
    // @Environment leest een waarde uit de omgeving van SwiftUI in plaats
    // van die zelf mee te geven: hier de functie om dit scherm te sluiten
    // (dismiss) en het huidige thema (theme).
    @Environment(\.dismiss) private var dismiss
    /// V20: sluiten vanuit het eigen paneel (kruisje / klik buiten / Esc).
    var onClose: (() -> Void)? = nil
    private func close() { if let onClose { onClose() } else { dismiss() } }
    @Environment(\.joeToepTheme) private var theme
    // @State is lokale, tijdelijke schermstatus (alleen van dit scherm):
    // hiermee onthoudt SwiftUI of een bevestigingsvenstertje open moet staan.
    @State private var confirmClear = false
    @State private var confirmReset = false
    @AppStorage("advancedModeV22") private var advancedMode = false
    /// V19.2: zoeken in de instellingen.
    @State private var search = ""

    // "var body: some View" is verplicht voor elke View: het beschrijft wat
    // er getekend wordt. "some View" betekent: een (voor Swift bekend, maar
    // voor ons niet uitgeschreven) specifiek View-type.
    var body: some View {
        // NavigationStack geeft dit scherm een navigatiebalk bovenaan en
        // laat je naar subschermen doorklikken (zoals bij NavigationLink
        // verderop), met een terugknop erbij.
        NavigationStack {
            // Form is een SwiftUI-container speciaal gemaakt voor
            // instellingenschermen: rijen worden netjes gegroepeerd en
            // gestyled zoals je gewend bent van bijvoorbeeld iOS-instellingen.
            Form {
                // V19.2: zoekresultaten (naam + uitleg + pagina) zolang er iets in het zoekveld staat.
                if !search.trimmingCharacters(in: .whitespaces).isEmpty {
                    let results = SettingHelp.search(search, advanced: advancedMode)  // V22.2
                    Section(results.isEmpty ? "No settings match “\(search)”" : "\(results.count) result\(results.count == 1 ? "" : "s")") {
                        ForEach(results, id: \.title) { result in
                            NavigationLink { page(result.page).formStyle(.grouped) } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(result.title)
                                    Text(result.help).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                    Text(result.page).font(.caption2).foregroundStyle(.tint)
                                }
                            }
                            .accessibilityIdentifier("settings.searchResult")
                        }
                    }
                } else {
                // Section groepeert een aantal rijen visueel bij elkaar,
                // eventueel met een titel en/of voetnoot ("footer").
                Section {
                    // HStack zet zijn inhoud horizontaal naast elkaar
                    // (spacing: 14 = 14 punten ruimte ertussen).
                    HStack(spacing: 14) {
                        // Het app-icoon: resizable() laat de afbeelding
                        // schalen, frame geeft de grootte, en clipShape knipt
                        // het af tot een afgeronde rechthoek.
                        Image("IconPreview" + AppIconController.shared.selection).resizable()
                            .frame(width: 54, height: 54).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        // VStack zet zijn inhoud verticaal onder elkaar
                        // (hier: linksuitgelijnd, met kleine tussenruimte).
                        VStack(alignment: .leading, spacing: 3) {
                            Text("JoeToep \(AppConstants.version)").font(.headline)
                            // De kleur van deze tekst hangt af van de
                            // voorwaarde vóór het vraagteken (?): oranje als
                            // de licentie/signing bijna verloopt, anders het
                            // standaard grijstintje "secondary".
                            Text(SigningInfo.summary).font(.caption)
                                .foregroundStyle(SigningInfo.expiresSoon ? .orange : .secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                // Deze Section met de titel "Settings" bevat de links naar
                // elke instellingencategorie. link(...) is de hulp-functie
                // hieronder die zo'n rij met icoon + naam + subscherm bouwt.
                // V17.1: eenvoudige indeling voor iedereen; technische opties staan onder "Advanced".
                // V20: overzichtelijke indeling in groepen, elk onderdeel met een korte uitleg.
                Section("Basics") {
                    link("General", "gearshape.fill", .gray, "Start page, search engine, new tab page, default browser") {
                        BrowserSettings(settings: settings, session: session, confirmClear: $confirmClear)
                    }
                    link("Appearance", "paintbrush.fill", .pink, "Theme, colours, app icon, tabs, animations") { AppearanceSettings(settings: settings) }
                    link("Menu bar & buttons", "menubar.rectangle", .teal, "Which buttons you see, size, hold actions") {
                        LayoutSettings(settings: settings)
                    }
                    link("Tabs, sidebar & search bar", "sidebar.left", .indigo, "Vertical tabs, groups, pinned tabs, ⌘T search bar") { SidebarAndCommandBarSettings() }
                    link("Top bar auto-hide", "rectangle.expand.vertical", .mint, "Hide tabs and buttons automatically") { AutoHideSettings() }
                    // V26: Arc/Dia-functies.
                    link(SettingHelp.v26Page, "square.stack.3d.up.fill", .purple, "Spaces, Split View, Peek, Boosts and the page assistant") { V26Settings() }
                }
                Section("Watching & listening") {
                    link("Playback & Picture in Picture", "pip.fill", .red, "Fullscreen, theater mode, speed, gestures, PiP") { PlaybackSettings(settings: settings, session: session) }
                    link("New tab page", "square.grid.2x2.fill", .purple, "Sections, order, shortcuts, background") { NewTabCustomizeForm() }
                    link("Music & Spotify", "music.note", .green, "Spotify control, now playing, sleep timer") { MusicSettings() }
                }
                Section("Devices & files") {
                    link("Sync & devices", "arrow.triangle.2.circlepath", .green, "Tabs and playback between Mac, iPhone and iPad") { SyncSettings(settings: settings) }
                    link("Downloads", "arrow.down.circle.fill", .blue, "Saved videos and audio for offline") { DownloadsView() }
                }
                Section("Privacy & blocking") {
                    link("Privacy & cookies", "hand.raised.fill", .indigo, "Cookies, website data, private tabs") { PrivacySettings(settings: settings) }
                    link("Ad blocking & SponsorBlock", "shield.lefthalf.filled", .orange, "Block ads, skip sponsor segments") {
                        Form {
                            Section {
                                NavigationLink("Ad blocking") { AdBlockSettings(settings: settings, session: session).navigationTitle("Ad blocking") }
                                NavigationLink("SponsorBlock (skip sponsors)") { SponsorBlockSettingsView(settings: settings, session: session).navigationTitle("SponsorBlock") }
                            } footer: { Text("Ads are blocked and sponsor segments are skipped by default.") }
                        }.formStyle(.grouped)
                    }
                }
                // V22: geen losse "advanced"-hoek meer voor iedereen: één schakelaar. Uit = alleen wat een
                // gewone gebruiker nodig heeft; aan = élke optie (ook de nerd-opties) op zijn eigen pagina.
                Section {
                    Toggle(isOn: $advancedMode.animation(Motion.quick())) {
                        VStack(alignment: .leading, spacing: 2) { Text("Advanced mode"); Text("Show every option, including the technical ones").font(.caption).foregroundStyle(.secondary) }
                    }
                    .accessibilityIdentifier("settings.advancedMode")
                    if advancedMode {
                        link("Internals & diagnostics", "wrench.and.screwdriver.fill", .gray, "Curves, WebKit tweaks, logs, experiments") { AdvancedSettings(settings: settings, session: session) }
                    }
                } footer: { Text(advancedMode ? "All options are visible. Technical options are marked with a wrench." : "Only the everyday options are shown. Turn on Advanced mode to see everything.") }
                // Deze losse Section bevat de "gevaarlijke" reset-knop.
                // role: .destructive geeft de knop een rode/waarschuwende
                // kleur, en tikken zet alleen confirmReset op true (de echte
                // reset gebeurt pas na bevestiging, zie confirmationDialog
                // hieronder).
                Section {
                    Button("Reset all preferences…", role: .destructive) { confirmReset = true }
                    detail("Resets every setting to its default. Tabs, bookmarks, history and sign-in stay.")
                }
                }
            }
            #if os(iOS)
            .searchable(text: $search, prompt: "Search settings")
            #else
            // Mac: zoekveld bovenaan in het formulier (rechtsboven staat het kruisje).
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search settings", text: $search).textFieldStyle(.plain)
                    if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain) }
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))
                .padding(.leading, 16).padding(.trailing, 56).padding(.vertical, 10)
                .background(.bar)
            }
            #endif
            // formStyle(.grouped) kiest de "gegroepeerde" opmaak van het
            // formulier, navigationTitle zet de titel in de navigatiebalk.
            .formStyle(.grouped)
            .navigationTitle("Settings")
            // toolbar voegt knoppen toe aan de navigatiebalk; hier een
            // "Done"-knop rechtsboven die het scherm sluit met dismiss().
        }
        // V20: altijd zichtbaar kruisje rechtsboven (ook op elke subpagina); Esc sluit ook.
        .closesOnEscape { close() }
        .overlay(alignment: .topTrailing) {
            // V21: even groot als de terugknop (Mac: 28 pt toolbarknop; iPhone/iPad: 44 pt glasknop).
            Button { close() } label: {
                Image(systemName: "xmark").font(.system(size: SettingsCloseMetrics.glyph, weight: .semibold))
                    .frame(width: SettingsCloseMetrics.size, height: SettingsCloseMetrics.size)
                    .contentShape(Circle())
                    .joeToepGlass(in: Circle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .help("Close settings (Esc)")
            .accessibilityLabel("Close settings")
            .accessibilityIdentifier("settings.done")
            .padding(.top, SettingsCloseMetrics.top).padding(.trailing, SettingsCloseMetrics.trailing)
        }
        // confirmationDialog toont een bevestigingsvenstertje zodra de
        // gekoppelde @State-waarde (met een $ ervoor: een Binding, zodat het
        // venstertje de waarde ook zelf terug op false kan zetten) true
        // wordt. Hier: eerst bevestigen voordat websitedata echt wordt
        // gewist, met de actie session.clearWebsiteData.
        .confirmationDialog("Clear cookies, cache and website storage?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear data", role: .destructive, action: session.clearWebsiteData)
            Button("Cancel", role: .cancel) {}
        } message: { Text("You will be signed out.") }
        // Dezelfde soort bevestiging, maar dan voor het terugzetten van alle
        // instellingen (settings.resetPreferences, zie AppSettings.swift).
        .confirmationDialog("Reset all JoeToep preferences?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive, action: settings.resetPreferences)
            Button("Cancel", role: .cancel) {}
        }
    }

    /// V19.2: de instellingenpagina bij een zoekresultaat.
    @ViewBuilder private func page(_ name: String) -> some View {
        switch name {
        case "General": BrowserSettings(settings: settings, session: session, confirmClear: $confirmClear).navigationTitle(name)
        case "Appearance": AppearanceSettings(settings: settings).navigationTitle(name)
        case "Menu bar & buttons": LayoutSettings(settings: settings).navigationTitle(name)
        case "Privacy & cookies": PrivacySettings(settings: settings).navigationTitle(name)
        case "Sync & devices": SyncSettings(settings: settings)
        case "New tab page": NewTabCustomizeForm().navigationTitle(name)
        case "Music & Spotify": MusicSettings().navigationTitle(name)
        case "Top bar auto-hide": AutoHideSettings().navigationTitle(name)
        case "Tabs, sidebar & search bar": SidebarAndCommandBarSettings().navigationTitle(name)
        case "Ad blocking & SponsorBlock": AdBlockSettings(settings: settings, session: session).navigationTitle("Ad blocking")
        // V22.2: ook de pagina's waar zoekresultaten écht staan (subpagina's en Internals).
        case "SponsorBlock": SponsorBlockSettingsView(settings: settings, session: session).navigationTitle(name)
        case "Tabs": TabSettings(settings: settings).navigationTitle(name)
        case "Audio visualizer": VisualizerSettings(settings: settings).navigationTitle(name)
        case "Focus filters": FocusSettings(settings: settings).navigationTitle(name)
        case "Internals & diagnostics": AdvancedSettings(settings: settings, session: session).navigationTitle(name)
        case SettingHelp.v26Page: V26Settings().navigationTitle(name)
        default: PlaybackSettings(settings: settings, session: session).navigationTitle("Playback & Picture in Picture")
        }
    }

    // Hulp-functie die telkens dezelfde soort rij bouwt: een klikbare link
    // naar een subscherm, met een gekleurd icoontje ervoor. "<Destination: View>"
    // is een generic: deze functie werkt voor eender welk subscherm-type,
    // zolang het maar een View is. @ViewBuilder destination geeft de inhoud
    // van dat subscherm mee als een stukje SwiftUI-code (een closure) dat
    // pas wordt uitgevoerd als de link echt wordt geopend.
    private func link<Destination: View>(_ title: String, _ symbol: String, _ color: Color, _ subtitle: String? = nil,
                                         @ViewBuilder destination: @escaping () -> Destination) -> some View {
        // NavigationLink is de rij zelf: tik erop, en SwiftUI schuift naar
        // het scherm dat in "destination()" wordt opgebouwd.
        NavigationLink {
            destination()
                .formStyle(.grouped)
                .navigationTitle(title)
        } label: {
            // Label combineert tekst en icoon in de rij die je ziet vóór je
            // erop tikt: de titel als tekst, en een gekleurd rondje met
            // SF Symbol-icoontje ernaast.
            Label {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                    if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                }
            } icon: {
                Image(systemName: symbol).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 26, height: 26).background(color.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
        }
        .accessibilityIdentifier("settings.page." + title)
    }
}

// @ViewBuilder op een losse functie (niet in een struct) laat je een kleine,
// herbruikbare stukje SwiftUI-interface maken zonder er een hele eigen View
// struct voor te hoeven schrijven. detail(...) tekent een grijze,
// toelichtende tekstregel die overal in dit bestand wordt hergebruikt onder
// instellingen. fixedSize(horizontal: false, vertical: true) zorgt dat lange
// tekst over meerdere regels mag lopen in plaats van afgekapt te worden.
@ViewBuilder
func detail(_ text: String) -> some View {
    Text(text).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
}

// MARK: - Appearance

// "private struct" betekent: dit View-type is alleen binnen dit bestand
// bruikbaar. Elke subschermen-struct in dit bestand volgt hetzelfde recept:
// een @ObservedObject settings, en een Form met Secties vol Toggles/Pickers
// die rechtstreeks aan een instelling in AppSettings gekoppeld zijn.
private struct AppearanceSettings: View {
    @ObservedObject var settings: AppSettings
    var body: some View {
        Form {
            Section("Theme") {
                // Picker laat de gebruiker één keuze maken uit meerdere
                // opties. "selection: $settings.themeStyle" is een Binding:
                // de $ vooraan betekent "geef me een verwijzing naar deze
                // waarde", zodat de Picker settings.themeStyle direct kan
                // lezen én aanpassen (en dus meteen ook AppSettings' didSet
                // laat opslaan).
                SettingPicker("Theme", selection: $settings.themeStyle) {
                    // ForEach herhaalt een stukje interface voor elk element
                    // in een lijst; hier voor elke waarde van de enum
                    // ThemeStyle (ThemeStyle.allCases = alle mogelijke
                    // keuzes). ".tag(style)" koppelt deze rij aan die
                    // specifieke enum-waarde, zodat de Picker weet welke rij
                    // bij welke keuze hoort.
                    ForEach(ThemeStyle.allCases) { style in
                        Label { Text(style.title) } icon: {
                            Circle().fill(style.background).overlay(Circle().stroke(.gray.opacity(0.4))).frame(width: 14, height: 14)
                        }.tag(style)
                    }
                }
                SettingPicker("Accent colour", selection: $settings.accentChoice) {
                    ForEach(AccentChoice.allCases) { choice in
                        Label { Text(choice.title) } icon: {
                            Circle().fill(choice.color(custom: settings.customAccentHex)).frame(width: 14, height: 14)
                        }.tag(choice)
                    }
                }
                // Deze regel verschijnt alleen als de gekozen accentkeuze
                // ".custom" is. ColorPicker laat de gebruiker zelf een kleur
                // kiezen; omdat settings.customAccentHex een tekst (hex-
                // code) is en geen Color, wordt hier handmatig een Binding
                // gemaakt: get haalt de tekst op en zet die om naar een
                // Color, set doet het omgekeerde zodra de gebruiker een
                // nieuwe kleur kiest.
                if settings.accentChoice == .custom {
                    ColorPicker("Custom accent", selection: Binding(
                        get: { Color(hexString: settings.customAccentHex) ?? .red },
                        set: { settings.customAccentHex = $0.hexString }), supportsOpacity: false)
                }
                detail("The theme colours JoeToep's menu bar, tabs and settings. YouTube itself stays in its dark theme.")
            }
            AdvancedSection("Icons in the app") {
                // "$0" is de kortere schrijfwijze voor het eerste (en hier
                // enige) argument van de closure: in plaats van "{ item in
                // Text(item.title) }" mag je "{ Text($0.title) }" schrijven.
                SettingPicker("Style", selection: $settings.iconVariant) {
                    ForEach(["Classic", "Outline", "Clean & minimal"], id: \.self) { group in
                        Section(group) {
                            ForEach(IconVariant.allCases.filter { $0.group == group }) { Text($0.title).tag($0) }
                        }
                    }
                }
                IconVariantGallery(settings: settings)
                SettingPicker("Weight", selection: $settings.iconWeight) {
                    ForEach(IconWeightChoice.allCases) { Text($0.title).tag($0) }
                }
                SettingPicker("Colouring", selection: $settings.iconRendering) {
                    ForEach(IconRendering.allCases) { Text($0.title).tag($0) }
                }
                // Een klein voorbeeldrijtje iconen dat meteen laat zien hoe
                // de bovenstaande drie keuzes er in het echt uitzien.
                IconStylePreview(theme: settings.theme)
            }
            Section("Tabs & text") {
                SettingPicker("Tab shape", selection: $settings.tabShape) {
                    ForEach(TabShape.allCases) { Text($0.title).tag($0) }
                }
                // V16.2.1: one slider for the size of all text in the app (menus, tabs, settings).
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Text size")
                        // Spacer duwt de tekst ervoor naar links en de tekst
                        // erna naar rechts, door alle beschikbare ruimte
                        // ertussen op te vullen.
                        Spacer()
                        // Rekent het percentage uit de kommawaarde (bijv.
                        // 1.2 -> "120 %"). monospacedDigit() zorgt dat de
                        // cijfers niet heen en weer springen als het getal
                        // verandert.
                        Text("\(Int((settings.textScale * 100).rounded())) %").monospacedDigit().foregroundStyle(.secondary)
                    }
                    // Slider is een schuifbalk. "in: 0.7...2.0" is het bereik
                    // (van 70% tot 200%), "step: 0.05" betekent dat hij in
                    // stapjes van 0.05 (5%) springt. De labels ervoor/erna
                    // zijn kleine iconen die de betekenis van de uiteinden
                    // van de balk tonen.
                    Slider(value: $settings.textScale, in: 0.7...2.0, step: 0.05) {
                        Text("Text size")
                    } minimumValueLabel: { Image(systemName: "textformat.size.smaller") }
                      maximumValueLabel: { Image(systemName: "textformat.size.larger") }
                    .labelsHidden()   // V17.1: het label staat al erboven (anders op de Mac dubbel)
                    // Zet de tekstgrootte direct terug op 100%. disabled(...)
                    // grijst de knop uit zodra hij al op 100% staat, zodat
                    // duidelijk is dat er niets te doen valt.
                    Button("Normal size (100 %)") { settings.textScale = 1 }
                        .buttonStyle(.bordered).controlSize(.small).disabled(settings.textScale == 1)
                }
                SettingPicker("Tab text", selection: $settings.tabTextSize) {
                    ForEach(TabTextSize.allCases) { Text($0.title).tag($0) }
                }
                SettingPicker("Close buttons", selection: $settings.tabCloseButtons) {
                    ForEach(TabCloseButtons.allCases) { Text($0.title).tag($0) }
                }
                // Toggle is de klassieke aan/uit-schakelaar. "isOn:
                // $settings.showTabIcons" koppelt hem rechtstreeks aan de
                // Bool-instelling.
                SettingToggle("Show tab icons", isOn: $settings.showTabIcons)
            }
            AdvancedSection("Motion") {
                SettingPicker("Animations", selection: $settings.animationStyle) {
                    ForEach(AnimationStyle.allCases) { Text($0.title).tag($0) }
                }
                // AnimationSpeedSlider is een eigen, herbruikbaar
                // slider-component (helemaal onderaan dit bestand
                // uitgelegd) dat een normale schuifbalk vervangt omdat de
                // snelheid over een heel groot bereik moet kunnen lopen.
                AnimationSpeedSlider(title: "Speed", value: $settings.animationSpeed)
                detail("Fast and smooth by default. Every animation can get its own curve and speed in Advanced settings.")
            }
            // V17.1: meer weergave-instellingen op eigen pagina's.
            Section("More appearance") {
                NavigationLink { TabSettings(settings: settings).navigationTitle("Tabs") } label: { Label("Tabs", systemImage: "square.on.square") }
                NavigationLink { LayoutSettings(settings: settings).navigationTitle("Menu bar & buttons") } label: { Label("Menu bar & buttons", systemImage: "menubar.rectangle") }
                NavigationLink { VisualizerSettings(settings: settings).navigationTitle("Audio visualizer") } label: { Label("Audio visualizer", systemImage: "waveform") }
            }
            Section("App icon") {
                IconPickerGrid()
                // "if let error = ..." is Swifts manier om veilig met een
                // optionele waarde (die er wel of niet kan zijn, hier
                // AppIconController.shared.error) om te gaan: de tekst wordt
                // alleen getoond als er ook echt een foutmelding is.
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

// Klein voorbeeldrijtje van app-iconen dat de gekozen stijl/dikte/kleuring
// toont zonder dat de gebruiker echt iets hoeft te wijzigen.
private struct IconStylePreview: View {
    let theme: JoeToepTheme
    var body: some View {
        HStack(spacing: 18) {
            // "id: \.self" vertelt ForEach dat elke tekst uit de lijst zelf
            // als unieke identiteit gebruikt mag worden (nodig omdat dit
            // gewone Strings zijn, geen eigen type met een id).
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
            AdvancedSection("Automatic tab summary") {
                SettingToggle("Summarise video titles in tabs", isOn: $settings.aiTabSummary)
                    .accessibilityIdentifier("settings.aiTabSummary")
                // "!settings.aiTabSummary" betekent "niet aiTabSummary": als
                // de samenvatting uitstaat, wordt deze Picker uitgegrijsd
                // (disabled) omdat de lengte er dan niet toe doet.
                SettingPicker("Length", selection: $settings.tabSummaryLength) {
                    ForEach(TabSummaryLength.allCases) { Text($0.title).tag($0) }
                }.disabled(!settings.aiTabSummary)
                SettingToggle("Use Apple Intelligence when available", isOn: $settings.useAppleIntelligence)
                    .disabled(!settings.aiTabSummary)
                // LabeledContent toont een label met daarnaast een
                // alleen-lezen waarde (hier of Apple Intelligence op dit
                // toestel beschikbaar is) — geen instelling om te wijzigen.
                LabeledContent("Apple Intelligence on this device", value: TabTitleSummarizer.appleIntelligenceAvailable ? "Available" : "Not available")
                detail("On: a short summary of the video in a few words, made on-device (Apple Intelligence) or with JoeToep's built-in shortener. Off: the tab shows the full video title. Tabs never just say “YouTube”.")
            }
            Section("Closing") {
                SettingPicker("Close inactive tabs after", selection: $settings.tabLifetime) {
                    ForEach(TabLifetime.allCases) { Text($0.title).tag($0) }
                }
                detail("Tabs you have not opened or played for this long close automatically in the background. Pinned tabs, the current tab, a playing tab and PiP are never closed. Closed tabs can be reopened (⌘⇧T or the + menu).")
            }
            Section("Opening") {
                SettingToggle("Open new tabs next to the current tab", isOn: $settings.openNewTabsNextToCurrent)
                SettingPicker("New tab page", selection: $settings.startPage) {
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
    // V22.2: zelfde sleutels/standaardwaarden als WebSession en BrowserWorkspace lezen.
    @AppStorage("newTabPageV192") private var newTabPage = true
    @AppStorage("pullActionV192") private var pullAction = "fullscreen"
    @AppStorage("backSwipeV192") private var backSwipe = false
    @AppStorage("advancedModeV22") private var advancedMode = false
    var body: some View {
        Form {
            Section("Picture in Picture") {
                SettingToggle("Automatic PiP when switching apps", isOn: $settings.automaticPiP)
                    .accessibilityIdentifier("settings.autoPiP")
                #if os(macOS)
                SettingToggle("Smart PiP with multiple displays", isOn: $settings.smartMultiMonitorPiP)
                    .disabled(!settings.automaticPiP)
                    .accessibilityIdentifier("settings.smartMultiMonitorPiP")
                #endif
                SettingToggle("Show PiP button in menu bar", isOn: $settings.showPiPButton)
                    .accessibilityIdentifier("settings.showPiPButton")
                SettingPicker("PiP return button opens", selection: $settings.pipReturnTarget) {
                    ForEach(PiPReturnTarget.allCases) { Text($0.title).tag($0) }
                }
                SettingToggle("Keep playing when returning from PiP", isOn: $settings.pipReturnKeepsPlaying)
                SettingToggle("Keep playing in PiP when opening another tab", isOn: $settings.pipOnTabSwitch)
                SettingToggle("New video takes over in fullscreen", isOn: $settings.fullscreenNewVideoFromPiP)
                    .disabled(!settings.pipOnTabSwitch)
                // V17: PiP-knop werkt ook op andere websites (Vimeo, Twitch, nieuwssites …).
                SettingToggle("Picture in Picture on all websites", isOn: $settings.pipOnAllSites)
                SettingToggle("Show Creator tools button (speed, A–B loop, BPM)", isOn: $settings.showCreatorTools)
                SettingToggle("Show speed buttons (slower / faster)", isOn: $settings.showSpeedControl)
                    .accessibilityIdentifier("settings.showSpeedControl")
                SettingToggle("Show Download button", isOn: $settings.showDownloadButton)
                    .accessibilityIdentifier("settings.showDownloadButton")
                detail("Open a new tab while a video plays: it continues in PiP. When you start a video in the new tab, the PiP video pauses and the new one plays fullscreen. Hold the PiP button for 0.3 s to reset PiP.")
            }
            // Deze hele sectie bestaat alleen op iOS (niet op de Mac), en
            // daarbinnen ook alleen als het apparaat een iPhone is (geen
            // iPad): rotatie-naar-fullscreen is een iPhone-specifiek gedrag.
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .phone {
                AutoRotateFullscreenSection()       // V23.1
                AdvancedSection("Rotation (iPhone)") {
                    SettingToggle("Fullscreen when rotating to landscape", isOn: $settings.fullscreenOnLandscape)
                    SettingToggle("Leave fullscreen when rotating back to portrait", isOn: $settings.exitFullscreenOnPortrait)
                    SettingToggle("Instant rotation (keep the page in portrait)", isOn: $settings.portraitLockForRotation)
                        .disabled(!settings.fullscreenOnLandscape)
                }
            }
            #endif
            Section("Gestures & scrubbing") {
                Stepper(value: $settings.swipeSeekSeconds, in: 1...30, step: 1) {
                    SettingLabel(title: "Swipe step: \(Int(settings.swipeSeekSeconds)) s")
                }
                Stepper(value: $settings.volumeStepPercent, in: 1...10, step: 1) {
                    SettingLabel(title: "Volume step: \(Int(settings.volumeStepPercent))%")
                }
                SettingToggle("Show YouTube controls while swiping", isOn: $settings.showControlsWhileScrubbing)
                SettingToggle("Preview thumbnail while scrubbing", isOn: $settings.scrubThumbnail)
                    .disabled(!settings.showControlsWhileScrubbing)
                SettingToggle("Show YouTube controls for arrow keys", isOn: $settings.arrowKeysShowControls)
                detail("Fullscreen: swipe sideways with two fingers (or Mac Mouse Fix) to scrub, up/down for volume. Arrow keys: ←/→ 5 s, ⌥ 30 s, ⌥⌘ 60 s; ↑/↓ five volume steps.")
            }
            #if os(macOS)
            if advancedMode { AdvancedGestureSettings() }
            #else
            TouchGestureSettings()
            #endif
            GesturePresetSection()
            Section("Browsing & fullscreen") {
                // V22.2: @AppStorage i.p.v. Binding(get: UserDefaults…) → de bediening ververst meteen.
                SettingToggle("Show new tab page (search & shortcuts)", isOn: $newTabPage)
                SettingPicker("Pull down action", selection: $pullAction) {
                    Text("Fullscreen (video pages)").tag("fullscreen")
                    Text("Refresh").tag("refresh")
                    Text("Off").tag("off")
                }
                SettingToggle("Swipe back to previous page", isOn: $backSwipe)
                detail("Horizontal swipes scrub the video by default, so swiping back is off. The Back button is always in the menu bar. Changes to swiping back apply to new tabs.")
            }
            AdvancedSection("Playback speed steps") {
                Stepper(value: $settings.speedStepSmall, in: 0.01...0.5, step: 0.01) {
                    SettingLabel(title: String(format: "Small step: %.2f×", settings.speedStepSmall))
                }
                Stepper(value: $settings.speedStepMedium, in: 0.05...1, step: 0.05) {
                    SettingLabel(title: String(format: "Medium step: %.2f×", settings.speedStepMedium))
                }
                Stepper(value: $settings.speedStepLarge, in: 0.1...2, step: 0.1) {
                    SettingLabel(title: String(format: "Large step: %.2f×", settings.speedStepLarge))
                }
                detail("− and + in the menu bar use the small step; tap the speed for all steps, a slider and presets. Mac: ⌥, / ⌥. small · ⌥⇧ medium · ⌃⌥ large · ⌥0 back to 1×.")
            }
            Section("Watching") {
                SettingToggle("Theater mode (full width)", isOn: $settings.theaterMode)
                SettingToggle("Fullscreen when a video loads and starts", isOn: $settings.automaticFullscreen)
                    .accessibilityIdentifier("settings.automaticFullscreen")
                SettingToggle("Fullscreen when you press play", isOn: $settings.fullscreenOnPlay)
                    .accessibilityIdentifier("settings.fullscreenOnPlay")
                SettingToggle("Leave fullscreen when paused", isOn: $settings.exitFullscreenOnPause)
                    .accessibilityIdentifier("settings.exitFullscreenOnPause")
                detail("Click a video and it starts in fullscreen; press play on a paused video and it goes fullscreen again. Leaving fullscreen on pause is off by default.")
                SettingToggle("Keep the screen on while a video plays", isOn: $settings.keepScreenAwake)
                SettingToggle("Turn off video captions", isOn: $settings.disableCaptions)
                SettingToggle("Turn off thumbnail preview captions", isOn: $settings.disablePreviewCaptions)
            }
            Section("Quality") {
                SettingPicker("Resolution preference", selection: $settings.quality) {
                    ForEach(PlaybackQualityPreference.allCases) { Text($0.title).tag($0) }
                }
                SettingToggle("Save data on cellular & hotspot", isOn: $settings.dataSaverOnCellular)
                // Dit is een gewone Swift "if" (geen compiler-conditie zoals
                // #if): deze Picker verschijnt of verdwijnt tijdens het
                // gebruik van de app, afhankelijk van de Toggle hierboven.
                if settings.dataSaverOnCellular {
                    SettingPicker("Quality on cellular / hotspot", selection: $settings.cellularQuality) {
                        ForEach(PlaybackQualityPreference.allCases) { Text($0.title).tag($0) }
                    }
                }
                detail("Off by default: the normal quality is used everywhere, also on mobile data or a personal hotspot such as “eiFoon”. On: JoeToep switches to the quality above whenever the connection is cellular, a hotspot or Low Data Mode.")
            }
            AdvancedSection("Media controls") {
                detail("Control Center, the Lock Screen and the ⏯ key control the video through Now Playing. When another app (Spotify, Podcasts) starts playing afterwards, the system hands the controls to that app until JoeToep plays again.")
            }
        }
    }
}

// MARK: - Advanced

private struct AdvancedSettings: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var session: WebSession
    // Bouwt een Binding<AnimationProfile> voor één animatie-onderdeel
    // (kind), zodat een Picker/Slider verderop rechtstreeks kan lezen én
    // schrijven in settings.animationProfiles[...], ook al bestaat er voor
    // dat onderdeel misschien nog geen eigen profiel (dan geldt een leeg
    // AnimationProfile() als startpunt).
    private func profile(_ kind: AnimationKind) -> Binding<AnimationProfile> {
        Binding(get: { settings.animationProfiles[kind.rawValue] ?? AnimationProfile() },
                set: { settings.animationProfiles[kind.rawValue] = $0 })
    }
    var body: some View {
        Form {
            Section {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Careful: for tech nerds").font(.headline)
                        Text("These settings change how JoeToep works internally. Wrong values can make PiP, fullscreen or playback unreliable. If something breaks, use “Reset all preferences” on the main settings page.")
                            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                } icon: { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange) }
                .padding(.vertical, 4)
            }
            Section("Content") {
                NavigationLink("Focus filters (hide Shorts, community posts …)") { FocusSettings(settings: settings).navigationTitle("Focus filters") }
            }
            Section("Animations") {
                SettingPicker("Style for everything", selection: $settings.animationStyle) {
                    ForEach(AnimationStyle.allCases) { Text($0.title).tag($0) }
                }
                speedRow("Speed for everything", $settings.animationSpeed)
                // Voor elk animatie-onderdeel (bijv. tabs, fullscreen, PiP)
                // wordt hieronder een eigen, uitklapbare groep getekend.
                ForEach(AnimationKind.allCases) { kind in
                    // V16.2.1: always expanded (the arrow points down) and it cannot be
                    // collapsed: `isExpanded: .constant(true)` is a binding that never changes.
                    DisclosureGroup(kind.title, isExpanded: .constant(true)) {
                        // "Same as everything" wordt weergegeven als de stijl
                        // van dit onderdeel nil is (AnimationStyle?.none):
                        // dan geldt gewoon de algemene stijl van hierboven.
                        // .wrappedValue haalt de eigenlijke waarde uit een
                        // Binding op, zodat we die kunnen lezen of overschrijven.
                        SettingPicker("Style", selection: Binding(get: { profile(kind).wrappedValue.style },
                                                           set: { profile(kind).wrappedValue.style = $0 })) {
                            Text("Same as everything").tag(AnimationStyle?.none)
                            ForEach(AnimationStyle.allCases) { Text($0.title).tag(AnimationStyle?.some($0)) }
                        }
                        speedRow("Relative speed", Binding(get: { profile(kind).wrappedValue.speed },
                                                          set: { profile(kind).wrappedValue.speed = $0 }))
                    }
                }
                // Zet alle per-onderdeel profielen leeg en de algemene
                // stijl/snelheid terug naar hun standaardwaarde.
                // V22.2: standaardsnelheid is 1,6× (zoals resetPreferences en Motion), niet 1,25×.
                Button("Reset animations") { settings.animationProfiles = [:]; settings.animationSpeed = 1.6; settings.animationStyle = .smooth }
                detail("System transitions (Apple's fullscreen and PiP windows) are animated by iOS/macOS itself; JoeToep starts them as early as possible.")
            }
            Section("Picture in Picture internals") {
                SettingToggle("Start PiP after leaving fullscreen", isOn: $settings.pipOnFullscreenExit)
                SettingToggle("Keep PiP when returning to JoeToep", isOn: $settings.keepPiPOnReturn)
                SettingToggle("Protect background playback", isOn: $settings.backgroundProtection)
                SettingToggle("Enable direct PiP fallback", isOn: $settings.pipFallbackEnabled)
                    .accessibilityIdentifier("settings.pipFallback")
                SettingToggle("Fastest transitions", isOn: $settings.instantTransitions)
                #if os(macOS)
                SettingToggle("Bring JoeToep forward when native PiP ends", isOn: $settings.activateMacOnPiPExit)
                SettingToggle("Automatic floating video fallback", isOn: $settings.macFloatingFallback)
                #endif
            }
            Section("Fullscreen & player") {
                #if os(macOS)
                SettingPicker("Fullscreen player", selection: $settings.macFullscreenMode) {
                    ForEach(MacFullscreenMode.allCases) { Text($0.title).tag($0) }
                }
                #else
                SettingToggle("Use Apple player (off = Safe Fullscreen)", isOn: $settings.nativeFullscreen)
                    .accessibilityIdentifier("settings.nativeFullscreen")
                SettingToggle("Rotate fullscreen to landscape", isOn: $settings.rotateOnFullscreen)
                SettingToggle("Return to portrait after fullscreen", isOn: $settings.returnToPortrait)
                if UIDevice.current.userInterfaceIdiom == .phone {
                    SettingToggle("YouTube fullscreen instead of Apple player", isOn: $settings.phoneElementFullscreen)
                }
                SettingToggle("Apple streaming engine (360p, video AirPlay, inline auto-PiP)", isOn: $settings.appleStreamingEngine)
                    .accessibilityIdentifier("settings.appleEngine")
                #endif
                SettingPicker("Video sizing", selection: $settings.videoFit) {
                    ForEach(VideoFit.allCases) { Text($0.title).tag($0) }
                }
                SettingPicker("Pinch gesture", selection: $settings.pinchMode) {
                    ForEach(PinchMode.allCases) { Text($0.title).tag($0) }
                }
                Button("Reset video zoom", action: session.resetVideoZoom)
            }
            Section("Website") {
                SettingPicker("Website layout", selection: $settings.sitePresentation) {
                    ForEach(SitePresentation.allCases) { Text($0.title).tag($0) }
                }
                HStack {
                    Text("Page scale")
                    Slider(value: $settings.pageZoom, in: 0.75...1.5, step: 0.05)
                    Text("\(Int(settings.pageZoom * 100))%").monospacedDigit().frame(width: 46)
                }
                SettingToggle("Recover a terminated web process", isOn: $settings.recoverWebProcess)
            }
            Section("Ad blocking internals") {
                SettingToggle("Latest compatible EasyList rules", isOn: $settings.experimentalFilters)
                    .accessibilityIdentifier("settings.experimentalFilters")
                Button(session.isUpdatingFilters ? "Checking source…" : "Check for latest experimental rules", action: session.updateExperimentalFilters)
                    .disabled(session.isUpdatingFilters)
                Text(session.experimentalFilterStatus).font(.caption).textSelection(.enabled)
            }
            Section("SponsorBlock server") {
                TextField("Server", text: $settings.sponsorBlock.serverURL).autocorrectionDisabled()
                Button("Use the official server") { settings.sponsorBlock.serverURL = "https://sponsor.ajay.app" }
            }
            Section("Diagnostics") {
                NavigationLink("Diagnostics & PiP log") {
                    DiagnosticsSettings(settings: settings, session: session).formStyle(.grouped).navigationTitle("Diagnostics")
                }
                Button("Force refresh the player now") { session.forceRefresh() }
            }
        }
    }
    private func speedRow(_ title: String, _ value: Binding<Double>) -> some View {
        AnimationSpeedSlider(title: title, value: value)
    }
}

// MARK: - Ad blocking

private struct AdBlockSettings: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var session: WebSession
    var body: some View {
        Form {
            Section {
                SettingToggle("Block ads", isOn: $settings.blockAds)
                SettingToggle("Hide ad cards and promoted tiles", isOn: $settings.hideAdCards)
            }
            AdvancedSection("Strictness") {
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
                SettingToggle("SponsorBlock", isOn: $settings.sponsorBlock.enabled)
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
            AdvancedSection("Behaviour") {
                SettingToggle("Show a notice with Undo after skipping", isOn: $settings.sponsorBlock.showNotice)
                Stepper("Notice duration: \(Int(settings.sponsorBlock.noticeSeconds)) s", value: $settings.sponsorBlock.noticeSeconds, in: 2...10, step: 1)
                SettingToggle("Show segments in the progress bar", isOn: $settings.sponsorBlock.showMarkers)
                SettingToggle("Skip each segment only once", isOn: $settings.sponsorBlock.skipOnlyOnce)
                SettingPicker("Ignore segments shorter than", selection: $settings.sponsorBlock.minimumDuration) {
                    ForEach([0.0, 1, 2, 3, 5, 10], id: \.self) { Text($0 == 0 ? "Never" : "\(Int($0)) s").tag($0) }
                }
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
            // V17.1: standaardbrowser.
            DefaultBrowserSection()
            Section("Browsing") {
                SettingToggle("Open other websites in JoeToep", isOn: $settings.openWebLinksInApp)
                // V17: navigatie-gedrag.
                SettingToggle("Back on the first page closes the tab", isOn: $settings.backClosesTab)
                SettingToggle("Show new tabs immediately (middle-click, Open in New Tab)", isOn: $settings.switchToNewTabs)
                SettingPicker("Address bar searches with", selection: $settings.searchEngine) {
                    ForEach(SearchEngine.allCases) { Text($0.title).tag($0) }
                }
                detail("Choose Google here to search the web instead of YouTube when you type something that is not a web address. Type in the address bar (tap the selected tab): a web address opens directly, anything else searches with the engine above. Per tab: ⋯ › Request Desktop/Mobile Website and zoom.")
            }
            Section("History & privacy") {
                SettingToggle("Remember browsing history", isOn: $settings.recordHistory)
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
    @AppStorage("oneBarLayoutV21") private var oneBar = true
    var body: some View {
        Form {
            #if os(macOS)
            Section {
                Toggle("One bar: tabs and buttons together", isOn: $oneBar)
            } footer: { Text("Like Safari: back, forward and the other buttons sit in the same bar as the tabs, right next to the window buttons. Uses the least vertical space.") }
            #else
            if UIDevice.current.userInterfaceIdiom == .pad {
                Section {
                    Toggle("One bar: tabs and buttons together", isOn: $oneBar)
                } footer: { Text("Like Safari on iPad: all buttons sit in the tab bar at the top, so the page gets the most room.") }
            }
            #endif
            AdvancedSection("Size") {
                SettingPicker("Menu bar buttons", selection: $settings.toolbarDensity) {
                    ForEach(ToolbarDensity.allCases) { Text($0.title).tag($0) }
                }
                detail("Eight sizes. Cozy, Medium and Roomy sit just below Large. Hold or middle-click Home, Subscriptions or Library to open them in a new tab; hold Refresh to force-refresh the player. Settings stays reachable with ⌘, and the ⋯ menu when its button is hidden.")
            }
            Section("Layout") {
                Menu {
                    ForEach(ToolbarPreset.allCases) { preset in
                        Button(preset.title) { preset.apply(to: settings) }
                    }
                } label: {
                    Label("Apply a menu bar layout…", systemImage: "rectangle.3.group")
                }
                .accessibilityIdentifier("settings.toolbarPreset")
                detail("Minimal keeps only Back/Forward, Home, speed, PiP, ⋯ and Settings in view — everything else stays one tap away in ⋯. Fine-tune each button below.")
            }
            Section("Buttons") {
                #if os(iOS)
                SettingToggle("Show JoeToep / #yolo", isOn: $settings.showBrand)
                #endif
                SettingToggle("Show Back and Forward buttons", isOn: $settings.showNavigationControls)
                SettingToggle("Show Refresh button", isOn: $settings.showRefreshButton)
                SettingToggle("Show Home button", isOn: $settings.showHomeButton)
                SettingToggle("Show Subscriptions button", isOn: $settings.showSubscriptionsButton)
                SettingToggle("Show Library button", isOn: $settings.showLibraryButton)
                SettingToggle("Show resolution (4K) button", isOn: $settings.showQualityButton)
                #if os(iOS)
                SettingToggle("Show AirPlay button", isOn: $settings.showAirPlayButton)
                #endif
                SettingToggle("Show Settings button", isOn: $settings.showSettingsButton)
                SettingToggle("Show New Tab (+) button", isOn: $settings.showNewTabButton)
                SettingToggle("Show History button", isOn: $settings.showHistoryButton)
                SettingToggle("Show Playlist / Watch later button", isOn: $settings.showPlaylistButton)
                SettingToggle("Show Bookmark button", isOn: $settings.showBookmarkButton)
                SettingToggle("Show More (⋯) browser menu", isOn: $settings.showMoreMenu)
                SettingToggle("Show connection and playback status", isOn: $settings.showConnectionStatus)
                SettingToggle("Edge-to-edge webpage", isOn: $settings.edgeToEdge)
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
                SettingToggle("Hide Shorts", isOn: $settings.blockShortsNavigation)
                SettingToggle("Hide posts and announcements", isOn: $settings.blockPostsNavigation)
                SettingToggle("Hide Premium / members-only cards", isOn: $settings.blockPremiumDestinations)
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


// MARK: - V16.2.1 animation speed slider

/// A speed slider with an extreme range: 0.05× (20 times SLOWER) up to 20× (20 times FASTER).
///
/// Why a "logarithmic" slider? With a normal slider from 0.05 to 20, the whole slow half
/// (0.05…1) would be squeezed into the first 5 % of the track. On a logarithmic track every
/// doubling takes the same distance: 0.25 → 0.5 → 1 → 2 → 4 are evenly spaced, and 1× sits
/// exactly in the middle. The slider works on log₂(speed); we convert back and forth.
struct AnimationSpeedSlider: View {
    let title: String                 // label on the left, e.g. "Speed for everything"
    @Binding var value: Double        // the real speed factor that is saved in the settings
    static let range: ClosedRange<Double> = 0.05...20   // min and max speed factor

    /// Converts between the saved speed (e.g. 2.0) and the slider position (log₂ 2.0 = 1.0).
    private var position: Binding<Double> {
        Binding(
            get: { log2(min(max(value, Self.range.lowerBound), Self.range.upperBound)) },
            set: { newPosition in
                let speed = pow(2, newPosition)                  // back from log₂ to a factor
                // Round to 2 significant steps so the numbers stay readable (1.00, 1.25, 12.0…).
                value = speed < 1 ? (speed * 100).rounded() / 100 : (speed * 20).rounded() / 20
            })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(label).monospacedDigit().foregroundStyle(.secondary)  // e.g. "2.50× faster"
            }
            Slider(value: position, in: log2(Self.range.lowerBound)...log2(Self.range.upperBound)) {
                Text(title)
            } minimumValueLabel: {
                Image(systemName: "tortoise.fill")                         // slow end
            } maximumValueLabel: {
                Image(systemName: "hare.fill")                             // fast end
            }
            .labelsHidden()   // V17.1: titel staat er al boven; voorkomt een dubbel label op de Mac
            HStack {                                                       // quick presets
                ForEach([0.25, 0.5, 1, 2, 4, 10], id: \.self) { preset in
                    Button(preset < 1 ? String(format: "%.2g×", preset) : String(format: "%.0f×", preset)) { value = preset }
                        .buttonStyle(.bordered).controlSize(.mini)
                }
            }
        }
        .padding(.vertical, 2)
    }
    /// Human text: "1.00× (normal)", "3.00× faster", "0.25× (4× slower)".
    private var label: String {
        if abs(value - 1) < 0.001 { return "1.00× (normal)" }
        if value > 1 { return String(format: "%.2f× faster", value) }
        return String(format: "%.2f× (%.1f× slower)", value, 1 / value)
    }
}


// MARK: - V17 Privacy & cookies

/// V17 — Privacy-instellingen: cookiebanners, volgen tegengaan, gegevens wissen en audio.
private struct PrivacySettings: View {
    @ObservedObject var settings: AppSettings
    @State private var cleared = false          // toont "Gewist" na de knop
    var body: some View {
        Form {
            Section("Cookie banners") {
                // Picker met de drie standen uit CookieBannerMode.
                SettingPicker("Cookie banners", selection: $settings.cookieBannerMode) {
                    ForEach(CookieBannerMode.allCases) { Text($0.title).tag($0) }
                }
                detail("Reject automatically clicks \"Reject all\" / \"Only necessary\" on every site (OneTrust, Cookiebot, Didomi, Quantcast, Usercentrics, Google/YouTube consent and many more), so you accept as little as possible. Hide only removes the banner without choosing.")
            }
            Section("Tracking protection") {
                SettingToggle("Block known trackers and ad pixels", isOn: $settings.blockTrackers)
                SettingToggle("Remove tracking parameters from links (utm_, fbclid, si …)", isOn: $settings.stripTrackingParameters)
                SettingToggle("Send Global Privacy Control (do not sell / share)", isOn: $settings.globalPrivacyControl)
                detail("These work on every website. Tracker blocking stops analytics and ad scripts such as Google Analytics, Facebook pixel, Hotjar and TikTok pixel from loading; page content is not affected.")
            }
            Section("Website data") {
                SettingToggle("Clear cookies and website data when JoeToep quits", isOn: $settings.clearDataOnQuit)
                Button(cleared ? "Cleared" : "Clear all cookies and website data now", role: .destructive) {
                    PrivacyCleaner.clearAll { cleared = true }
                }.disabled(cleared)
                detail("Clearing signs you out of YouTube and other sites. Private tabs never store anything.")
            }
            Section("Audio") {
                SettingToggle("Spatial audio for AirPods (movie mode, multichannel)", isOn: $settings.spatialAudio)
                detail("With AirPods Pro, AirPods Max and AirPods 4: stereo is spatialized with head tracking and Dolby Atmos / 5.1 is passed through. Choose Fixed, Head Tracked or Off in Control Center › volume slider › Spatial Audio. On the Mac this is controlled by macOS in the same place.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Privacy & cookies")
    }
}


// MARK: - V17.1 Audio visualizer

/// V17.1 — alle visualizer-instellingen op één pagina. `$settings.visualizerConfig.bars` is een
/// "binding" naar één veld binnen het pakketje: SwiftUI schrijft de wijziging direct terug.
private struct VisualizerSettings: View {
    @ObservedObject var settings: AppSettings
    private var on: Bool { settings.visualizerStyle != .off }
    var body: some View {
        Form {
            Section {
                SettingPicker("Style", selection: $settings.visualizerStyle) {
                    ForEach(VisualizerStyle.allCases) { Text($0.title).tag($0) }
                }
                SettingToggle("Also behind the tabs", isOn: $settings.visualizerInTabBar).disabled(!on)
            } footer: {
                Text("Off by default. It moves while a video plays and stops when paused. WebKit does not let apps read a video's sound without risking silence in Picture in Picture, so it follows the playback (and your BPM) instead of the exact audio.")
            }
            AdvancedSection("Colour") {
                SettingPicker("Colours", selection: $settings.visualizerConfig.colorMode) {
                    ForEach(VisualizerColorMode.allCases) { Text($0.title).tag($0) }
                }
                if settings.visualizerConfig.colorMode == .custom || settings.visualizerConfig.colorMode == .gradient {
                    ColorPicker("Colour", selection: Binding(
                        get: { Color(hexString: settings.visualizerConfig.colorA) ?? .red },
                        set: { settings.visualizerConfig.colorA = $0.hexString }))
                }
                slider("Opacity", $settings.visualizerConfig.opacity, 0.1...1, "%.0f %%", scale: 100)
                SettingToggle("Glow", isOn: $settings.visualizerConfig.glow)
            }.disabled(!on)
            AdvancedSection("Shape") {
                Stepper("Bars: \(settings.visualizerConfig.bars)", value: $settings.visualizerConfig.bars, in: 8...160, step: 4)
                slider("Height", $settings.visualizerConfig.height, 0.2...1, "%.0f %%", scale: 100)
                slider("Intensity", $settings.visualizerIntensity, 0.1...1, "%.0f %%", scale: 100)
                SettingPicker("Position", selection: $settings.visualizerConfig.placement) {
                    ForEach(VisualizerPlacement.allCases) { Text($0.title).tag($0) }
                }
                SettingToggle("Mirror (symmetric)", isOn: $settings.visualizerConfig.mirror)
                SettingToggle("Rounded bars", isOn: $settings.visualizerConfig.roundedCaps)
            }.disabled(!on)
            AdvancedSection("Motion") {
                slider("Speed", $settings.visualizerConfig.speed, 0.25...3, "%.2f×")
                slider("Smoothing", $settings.visualizerConfig.smoothing, 0...1, "%.0f %%", scale: 100)
                HStack {
                    Text("Pulse on BPM")
                    Spacer()
                    TextField("BPM", value: $settings.visualizerConfig.bpm, format: .number.precision(.fractionLength(0...1)))
                        .multilineTextAlignment(.trailing).frame(width: 70)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }
                Text("0 = free movement. Tip: tap the tempo in Creator tools, then enter it here.").font(.caption).foregroundStyle(.secondary)
            }.disabled(!on)
            Section {
                Button("Reset visualizer") { settings.visualizerConfig = VisualizerConfig(); settings.visualizerIntensity = 0.6 }
            }
        }
        .formStyle(.grouped)
    }
    private func slider(_ title: String, _ value: Binding<Double>, _ range: ClosedRange<Double>, _ format: String, scale: Double = 1) -> some View {
        HStack {
            Text(title)
            Slider(value: value, in: range)
            Text(String(format: format, value.wrappedValue * scale)).monospacedDigit().frame(width: 58, alignment: .trailing)
        }
    }
}


// MARK: - V17.1 Default browser

private struct DefaultBrowserSection: View {
    @State private var message: String?
    @State private var isDefault = DefaultBrowser.isDefault
    var body: some View {
        Section("Default browser") {
            #if os(macOS)
            LabeledContent("JoeToep is your default browser", value: isDefault ? "Yes" : "No")
            Button(isDefault ? "JoeToep is the default" : "Make JoeToep the default browser") {
                DefaultBrowser.request { message = $0; isDefault = DefaultBrowser.isDefault }
            }.disabled(isDefault)
            Text("If JoeToep doesn't appear or it doesn't stick: quit JoeToep, move it to the Applications folder, open it from there once, then choose it in System Settings › Desktop & Dock › Default web browser.")
                .font(.caption).foregroundStyle(.secondary)
            Button("Open Desktop & Dock settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension") { NSWorkspace.shared.open(url) }
            }
            #else
            Text("Apple only lets browsers with a special Apple entitlement become the default on iPhone and iPad. Apps installed with a free developer account can't get it, so iOS won't list JoeToep. Workaround below: open any link in JoeToep in two taps from the share sheet.")
                .font(.caption).foregroundStyle(.secondary)
            #endif
        }
        #if os(iOS)
        Section("Workaround: “Open in JoeToep” in the share sheet") {
            VStack(alignment: .leading, spacing: 6) {
                Text("1. Open the Shortcuts app › + › Add Action › search “URL” › choose **Get URLs from Input**.")
                Text("2. Add **Text** with: `joetoep://open?url=` followed by the variable *URLs*.")
                Text("3. Add **Open URLs** (input: the Text).")
                Text("4. Tap ⓘ › turn on **Show in Share Sheet**, input types: URLs and Safari web pages. Name it “Open in JoeToep”.")
                Text("Now in Safari, Mail, Messages or any app: Share › Open in JoeToep.")
            }
            .font(.caption)
            Button("Test: open YouTube via joetoep://") {
                if let url = URL(string: "joetoep://open?url=https://www.youtube.com") { UIApplication.shared.open(url) }
            }
            detail("Tip: an automation “When Safari opens → run Open in JoeToep” is possible too, but iOS asks each time.")
        }
        #endif
        if let message {
            Section { Text(message).font(.caption).foregroundStyle(.secondary) }
        }
    }
}

// MARK: - V18 Sync

/// V18: live tab-synchronisatie tussen Mac, iPad en iPhone (en de Watch als afstandsbediening).
private struct SyncSettings: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject private var sync = TabSyncService.shared
    var body: some View {
        Form {
            Section {
                SettingToggle("Live tab sync", isOn: $settings.tabSync)
                    .accessibilityIdentifier("settings.tabSync")
            }
            HandoffSettingsSection()
            Section("Nearby devices") {
                if sync.peers.isEmpty {
                    detail(settings.tabSync ? "Searching… Open JoeToep on your other devices (same wifi, or Bluetooth on). On iPhone/iPad allow Local Network for JoeToep." : "Sync is off.")
                } else {
                    ForEach(sync.peers, id: \.self) { name in
                        let state = sync.peerStates.values.first { $0.name.hasPrefix(name) || name.hasPrefix($0.name) }
                        let inSync = (state?.ackedVersion ?? 0) >= sync.currentVersion && sync.currentVersion > 0
                        HStack {
                            Label(name, systemImage: inSync ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                                .foregroundStyle(inSync ? .green : .orange)
                            Spacer()
                            Text(inSync ? "In sync · \(state?.tabCount ?? 0) tabs" : "Syncing…")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .accessibilityIdentifier("sync.peer")
                    }
                }
                if let last = sync.lastSync {
                    detail("Last change: \(last.formatted(date: .omitted, time: .standard))")
                }
            }
            if !sync.log.isEmpty {
                AdvancedSection("Activity") {
                    ForEach(Array(sync.log.prefix(30).enumerated()), id: \.offset) { _, line in
                        Text(line).font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                detail("Opening, closing or switching a tab, and playing, pausing or seeking a video, appears on your other devices within a fraction of a second. The newest change always wins. Only one device plays at a time: starting a video here pauses it elsewhere. Your Apple Watch uses your iPhone to browse and control playback.")
            }
        }
        .navigationTitle("Sync & devices")
    }
}


#if os(macOS)
/// V19.1 — Diepgaande instellingen voor vegen met trackpad en muis (ook Mac Mouse Fix).
private struct AdvancedGestureSettings: View {
    @AppStorage("nativeGesturesV191") private var native = true
    @AppStorage("gestureModeV191") private var mode = "continuous"
    @AppStorage("invertTrackpadXV191") private var invertTrackpadX = false
    @AppStorage("invertTrackpadYV191") private var invertTrackpadY = false
    @AppStorage("invertMouseXV191") private var invertMouseX = false
    @AppStorage("invertMouseYV191") private var invertMouseY = false
    @AppStorage("seekPerPointTrackpadV191") private var seekTrackpad = 0.05
    @AppStorage("seekPerPointMouseV191") private var seekMouse = 0.2
    @AppStorage("volumePerPointTrackpadV191") private var volumeTrackpad = 0.3
    @AppStorage("volumePerPointMouseV191") private var volumeMouse = 1.0
    @AppStorage("ignoreMomentumV191") private var ignoreMomentum = true
    @AppStorage("axisLockPointsV191") private var axisLock = 6.0
    @AppStorage("axisRatioV191") private var axisRatio = 1.3
    @AppStorage("stepThresholdV191") private var stepThreshold = 28.0
    @AppStorage("gesturesInWindowFullscreenV191") private var windowFullscreen = true
    @AppStorage("scrubInlineV192") private var scrubInline = true
    @AppStorage("seekThrottleMsV192") private var seekThrottle = 60.0

    var body: some View {
        Section("Trackpad & mouse gestures (fullscreen)") {
            Toggle("Native gestures (recommended)", isOn: $native)
            Toggle("Scrub with a sideways swipe on the normal (inline) player too", isOn: $scrubInline)
            Picker("Feel", selection: $mode) {
                Text("Continuous (smooth)").tag("continuous")
                Text("Steps").tag("steps")
            }
            detail("Continuous follows your fingers exactly; Steps jumps by the swipe/volume step above.")
        }
        AdvancedSection("Trackpad (MacBook)") {
            Toggle("Flip scrub direction", isOn: $invertTrackpadX)
            Toggle("Flip volume direction", isOn: $invertTrackpadY)
            slider("Scrub speed", $seekTrackpad, 0.005...0.5, "%.3f s/pt")
            slider("Volume speed", $volumeTrackpad, 0.02...2, "%.2f %%/pt")
            Toggle("Ignore momentum after lifting fingers", isOn: $ignoreMomentum)
        }
        AdvancedSection("Mouse (e.g. Razer + Mac Mouse Fix)") {
            Toggle("Flip scrub direction", isOn: $invertMouseX)
            Toggle("Flip volume direction", isOn: $invertMouseY)
            slider("Scrub speed", $seekMouse, 0.01...2, "%.2f s/pt")
            slider("Volume speed", $volumeMouse, 0.05...5, "%.2f %%/pt")
            detail("Mac Mouse Fix's smooth scrolling can look like a trackpad to macOS; if the direction is wrong, flip it in the Trackpad section instead.")
        }
        Section("For nerds") {
            slider("Axis lock distance", $axisLock, 0...30, "%.0f pt")
            slider("Axis dominance ratio", $axisRatio, 1...3, "%.2f×")
            slider("Step threshold", $stepThreshold, 4...80, "%.0f pt")
            slider("Seek rate limit (lower = more responsive)", $seekThrottle, 0...250, "%.0f ms")
            Toggle("Also in macOS window fullscreen", isOn: $windowFullscreen)
            TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                Text("Last gesture: " + (GestureScrubber.shared.lastSummary.isEmpty ? "—" : GestureScrubber.shared.lastSummary))
                    .font(.caption.monospaced()).foregroundStyle(.secondary)
            }
        }
    }
    private func slider(_ title: String, _ value: Binding<Double>, _ range: ClosedRange<Double>, _ format: String) -> some View {
        HStack {
            Text(title)
            Slider(value: value, in: range)
            Text(String(format: format, value.wrappedValue)).monospacedDigit().frame(width: 84, alignment: .trailing)
        }
    }
}
#endif


/// V19.2 — Scrubben met je vinger over de gewone (inline) speler op iPhone/iPad.
private struct TouchGestureSettings: View {
    @AppStorage("touchScrubV192") private var touchScrub = true
    @AppStorage("touchSeekPerPxV192") private var perPx = 0.25
    @AppStorage("invertTouchV192") private var invert = false
    var body: some View {
        AdvancedSection("Touch scrubbing (inline player)") {
            Toggle("Swipe over the video to scrub", isOn: $touchScrub)
            HStack {
                Text("Speed")
                Slider(value: $perPx, in: 0.02...2)
                Text(String(format: "%.2f s/pt", perPx)).monospacedDigit().frame(width: 76, alignment: .trailing)
            }
            Toggle("Flip direction", isOn: $invert)
            detail("Swipe sideways over a video that is not fullscreen. Up/down still scrolls the page. In fullscreen, Apple's player gestures apply.")
        }
    }
}

/// V19.2 — Voorinstellingen voor alle gebaren + terug naar standaard.
private struct GesturePresetSection: View {
    var body: some View {
        AdvancedSection("Gesture presets") {
            Button("Precise (small steps)") { Self.apply(seek: 0.02, mouseSeek: 0.08, volume: 0.15, touch: 0.1) }
            Button("Balanced (default)") { Self.reset() }
            Button("Fast (big jumps)") { Self.apply(seek: 0.15, mouseSeek: 0.6, volume: 0.8, touch: 0.8) }
            Button("Reset all gestures to defaults", role: .destructive) { Self.reset() }
                .accessibilityIdentifier("settings.resetGestures")
        }
    }
    static func apply(seek: Double, mouseSeek: Double, volume: Double, touch: Double) {
        let d = UserDefaults.standard
        d.set(seek, forKey: "seekPerPointTrackpadV191"); d.set(mouseSeek, forKey: "seekPerPointMouseV191")
        d.set(volume, forKey: "volumePerPointTrackpadV191"); d.set(volume * 3, forKey: "volumePerPointMouseV191")
        d.set(touch, forKey: "touchSeekPerPxV192")
    }
    static func reset() {
        let d = UserDefaults.standard
        for key in ["nativeGesturesV191", "gestureModeV191", "invertTrackpadXV191", "invertTrackpadYV191", "invertMouseXV191",
                    "invertMouseYV191", "seekPerPointTrackpadV191", "seekPerPointMouseV191", "volumePerPointTrackpadV191",
                    "volumePerPointMouseV191", "ignoreMomentumV191", "axisLockPointsV191", "axisRatioV191", "stepThresholdV191",
                    "gesturesInWindowFullscreenV191", "touchScrubV192", "touchSeekPerPxV192", "invertTouchV192", "scrubInlineV192",
                    "pullActionV192", "backSwipeV192"] { d.removeObject(forKey: key) }
    }
}

/// V20: tik op een voorbeeld om die icoonstijl te kiezen (alle outline- en minimalistische varianten).
private struct IconVariantGallery: View {
    @ObservedObject var settings: AppSettings
    private let symbols = ["chevron.backward", "house", "bookmark", "pip", "gearshape"]
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(IconVariant.allCases) { variant in
                    let theme = { var t = settings.theme; t.iconVariant = variant; return t }()
                    Button { settings.iconVariant = variant } label: {
                        VStack(spacing: 6) {
                            HStack(spacing: 8) {
                                ForEach(Array(symbols.enumerated()), id: \.offset) { i, name in
                                    Image(systemName: name).themedIcon(theme, size: 15, active: i == 2)
                                        .frame(width: 22, height: 26)
                                }
                            }
                            Text(variant.title).font(.caption2).lineLimit(1)
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(settings.iconVariant == variant ? settings.accentColor.opacity(0.18) : Color.primary.opacity(0.05)))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(settings.iconVariant == variant ? settings.accentColor : .clear, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
    }
}


/// V21: maat en plek van het kruisje, gelijk aan de terugknop van het platform.
enum SettingsCloseMetrics {
    #if os(macOS)
    static let size: CGFloat = 28, glyph: CGFloat = 12, top: CGFloat = 11, trailing: CGFloat = 12
    #else
    static var size: CGFloat { if #available(iOS 26.0, *) { return 44 } else { return 36 } }
    static let glyph: CGFloat = 17
    static var top: CGFloat { if #available(iOS 26.0, *) { return 4 } else { return 6 } }
    static let trailing: CGFloat = 16
    #endif
}


/// V22: sectie die alleen zichtbaar is met "Advanced mode" aan (Instellingen, bovenaan de lijst).
struct AdvancedSection<Content: View>: View {
    let title: String
    let content: Content
    @AppStorage("advancedModeV22") private var advanced = false
    init(_ title: String, @ViewBuilder content: () -> Content) { self.title = title; self.content = content() }
    var body: some View {
        if advanced {
            Section { content } header: { Label(title, systemImage: "wrench.and.screwdriver").labelStyle(.titleAndIcon) }
        }
    }
}
