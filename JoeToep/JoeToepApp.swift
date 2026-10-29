// Dit is het echte "startbestand" van de app: hier begint alles. Het vertelt
// het besturingssysteem welk venster geopend moet worden en (op de Mac) welke
// menu-opties er in de menubalk bovenin komen te staan.
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// @main markeert deze struct als het startpunt van de hele app: het
// besturingssysteem roept dit als eerste aan wanneer de app start.
@main
// "App" is een SwiftUI-protocol: elke SwiftUI-app moet hier een struct van
// maken die beschrijft welke schermen (Scenes) er zijn.
struct JoeToepApp: App {
    // Alleen op iOS: koppel een "AppDelegate" (ouderwetse iOS-hook voor
    // systeemgebeurtenissen, zoals opstarten/achtergrondtaken) aan de app.
    #if os(iOS)
    @UIApplicationDelegateAdaptor(JoeToepAppDelegate.self) private var appDelegate
    #endif
    // "body" van een App beschrijft de Scene(s): de vensters die de app kan
    // openen.
    /// V17: bij het starten eerst eventueel de websitegegevens wissen ("wissen bij afsluiten"),
    /// en een melding aanvragen voor het moment dat de app afsluit.
    init() {
        PrivacyCleaner.clearPendingAtLaunch()
        #if DEBUG
        // V17.1 stresstest: met "--cpu-load" houden 3 achtergrond-threads 4 minuten lang de
        // processor bezig, zodat UI-tests PiP en schermvullend "onder zware belasting" testen.
        if ProcessInfo.processInfo.arguments.contains("--cpu-load") {
            for _ in 0..<3 {
                Thread.detachNewThread {
                    let end = Date().addingTimeInterval(240)
                    var x = 1.0
                    while Date() < end { for i in 1...200_000 { x = (x * 1.000_001 + Double(i)).truncatingRemainder(dividingBy: 97) } }
                    if x < 0 { print(x) }   // voorkomt dat de compiler de lus wegoptimaliseert
                }
            }
        }
        #endif
        #if os(macOS)
        let quit = NSApplication.willTerminateNotification
        #else
        let quit = UIApplication.willTerminateNotification
        #endif
        NotificationCenter.default.addObserver(forName: quit, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { PrivacyCleaner.markForClearingOnQuit() }
        }
    }
    var body: some Scene {
        // WindowGroup maakt een venster aan met de titel "JoeToep" en het
        // interne id "main". De inhoud ertussen is wat er in dat venster
        // getoond wordt: hier RootView.
        WindowGroup("JoeToep", id: "main") {
            #if os(macOS)
            // Op de Mac geven we het venster een minimale breedte/hoogte
            // zodat het niet te klein gemaakt kan worden.
            RootView().frame(minWidth: 520, minHeight: 360)
            #else
            RootView()
            #endif
        }
        #if os(macOS)
        // Startgrootte van het venster, een titelbalk zonder zichtbare tekst,
        // en het toevoegen van eigen menu-commando's (zie BrowserCommands
        // hieronder) aan de macOS-menubalk.
        // V17.1: links van buitenaf gaan naar het bestaande venster (niet elke keer een nieuw venster).
        .handlesExternalEvents(matching: ["*"])
        .defaultSize(width: 1240, height: 800)
        .windowStyle(.hiddenTitleBar)
        #endif
        // V19.3: dezelfde menu's en sneltoetsen ook op iPad (met toetsenbord).
        .commands { BrowserCommands() }
    }
}
// Dit hele blok bestaat alleen op macOS: het definieert de extra menu's
// (Bestand, Bewerken, Geschiedenis, Tabbladen, Afspelen) in de menubalk.
// Commands is een SwiftUI-protocol voor het beschrijven van menustructuren.
struct BrowserCommands: Commands {
    // @FocusedValue leest een waarde die het momenteel actieve/gefocuste
    // venster heeft doorgegeven (hier: de acties die de browser-tab kan
    // uitvoeren, zoals nieuwe tab, terug, etc.). Is er geen actief venster
    // met acties, dan is dit nil.
    @FocusedValue(\.workspaceActions) private var actions
    // @Environment leest een waarde uit de "omgeving" van SwiftUI; hier een
    // functie waarmee je een nieuw venster kan openen.
    @Environment(\.openWindow) private var openWindow
    var body: some Commands {
        // CommandGroup(replacing:) vervangt een bestaand systeemmenu-onderdeel
        // (hier: het standaard "Nieuw"-item) door onze eigen knoppen.
        CommandGroup(replacing: .newItem) {
            // Elke Button heeft een titel, een actie (wat er gebeurt bij een
            // klik) en een sneltoets. .disabled(actions == nil) zorgt dat de
            // knop grijs/niet-klikbaar is als er geen actief venster is.
            Button("New Tab") { actions?.newTab() }.keyboardShortcut("t", modifiers: .command).disabled(actions == nil)
            Button("New Private Tab") { actions?.newPrivateTab() }.keyboardShortcut("n", modifiers: [.command, .shift]).disabled(actions == nil)
            Button("New Window") { openWindow(id: "main") }.keyboardShortcut("n", modifiers: .command)
            Button("Reopen Closed Tab") { actions?.reopenClosedTab() }.keyboardShortcut("t", modifiers: [.command, .shift]).disabled(actions == nil)
            // Divider tekent een scheidingslijntje tussen groepen menu-items.
            Divider()
            Button("Open Location…") { actions?.editAddress() }.keyboardShortcut("l", modifiers: .command).disabled(actions == nil)
            Divider()
            Button("Close Tab") { actions?.closeTab() }.keyboardShortcut("w", modifiers: .command).disabled(actions == nil)
            Button("Close Window") { actions?.closeWindow() }.keyboardShortcut("w", modifiers: [.command, .shift]).disabled(actions == nil)
        }
        // Vervangt het standaard "Instellingen"-menu-item.
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { actions?.openSettings() }.keyboardShortcut(",", modifiers: .command).disabled(actions == nil)
        }
        // Voegt eigen items toe ná het bestaande "Nieuw"-menugroepje.
        CommandGroup(after: .newItem) {
            Button("Reload Page") { actions?.reload() }.keyboardShortcut("r", modifiers: .command).disabled(actions == nil)
            Button("Force Refresh (restart player)") { actions?.forceRefresh() }.keyboardShortcut("r", modifiers: [.command, .shift]).disabled(actions == nil)
        }
        // Vervangt het standaard tekstbewerkingsmenu met onze eigen "Zoeken"
        // en "Open locatie" opties.
        CommandGroup(replacing: .textEditing) {
            Button("Find on Page…") { actions?.find() }.keyboardShortcut("f", modifiers: .command).disabled(actions == nil)
            Button("Open Location…") { actions?.editAddress() }.keyboardShortcut("k", modifiers: .command).disabled(actions == nil)
        }
        // CommandMenu maakt een heel nieuw menu (met eigen naam) in de
        // menubalk, hier "History" (Geschiedenis).
        CommandMenu("History") {
            Button("Back") { actions?.goBack() }.keyboardShortcut("[", modifiers: .command).disabled(actions == nil)
            Button("Forward") { actions?.goForward() }.keyboardShortcut("]", modifiers: .command).disabled(actions == nil)
            Divider()
            Button("Show Bookmarks & History") { actions?.showLibrary() }.keyboardShortcut("y", modifiers: .command).disabled(actions == nil)
            Button("Add / Remove Bookmark") { actions?.toggleBookmark() }.keyboardShortcut("d", modifiers: .command).disabled(actions == nil)
        }
        // Een apart menu voor alles wat met tabbladen te maken heeft.
        CommandMenu("Tabs") {
            Button("Show Next Tab") { actions?.nextTab() }.keyboardShortcut("]", modifiers: [.command, .shift]).disabled(actions == nil)
            Button("Show Previous Tab") { actions?.previousTab() }.keyboardShortcut("[", modifiers: [.command, .shift]).disabled(actions == nil)
            Button("Switch to Recent Tab") { actions?.recentTab() }.keyboardShortcut(.tab, modifiers: .option).disabled(actions == nil)
            Button("Duplicate Tab") { actions?.duplicateTab() }.keyboardShortcut("d", modifiers: [.command, .shift]).disabled(actions == nil)
            Button("Copy Link") { actions?.copyLink() }.keyboardShortcut("c", modifiers: [.command, .shift]).disabled(actions == nil)
            Button("Pin / Unpin Tab") { actions?.togglePin() }.disabled(actions == nil)
            Divider()
            // ForEach herhaalt hetzelfde stuk UI voor elk getal in het bereik
            // 1..<10 (dus 1 t/m 9): zo maken we automatisch 9 sneltoetsen
            // (Cmd+1 t/m Cmd+9) om snel naar een specifiek tabblad te springen.
            ForEach(1..<10) { number in
                // De laatste (9e) knop heet "Last Tab" in plaats van "Tab 9".
                // selectTab(number - 1) omdat tabbladen intern vanaf 0 tellen.
                Button(number == 9 ? "Last Tab" : "Tab \(number)") { actions?.selectTab(number - 1) }
                    .keyboardShortcut(KeyEquivalent(Character("\(number)")), modifiers: .command).disabled(actions == nil)
            }
        }
        // Eigen zoom-knoppen, toegevoegd ná de bestaande werkbalk-groep.
        CommandGroup(before: .toolbar) {
            Button("Show / Hide Sidebar") { NotificationCenter.default.post(name: .joeToepToggleSidebar, object: nil) }
                .keyboardShortcut("s", modifiers: .command)
        }
        CommandGroup(after: .toolbar) {
            Button("Zoom In") { actions?.zoomIn() }.keyboardShortcut("+", modifiers: .command).disabled(actions == nil)
            Button("Zoom Out") { actions?.zoomOut() }.keyboardShortcut("-", modifiers: .command).disabled(actions == nil)
            Button("Actual Size") { actions?.resetZoom() }.keyboardShortcut("0", modifiers: .command).disabled(actions == nil)
        }
        // Een klein menu voor het aan/uitzetten van Picture in Picture.
        CommandMenu("Playback") {
            Button("Toggle Picture in Picture") { actions?.pictureInPicture() }.keyboardShortcut("z", modifiers: .option).disabled(actions == nil)
            Divider()
            Button("Pause Everything") { MediaHub.shared.scan(); MediaHub.shared.pauseAll() }.keyboardShortcut(".", modifiers: [.command, .option])
        }
        // V20: Spotify bedienen vanuit JoeToep (Mac: de desktopapp; iPhone/iPad: Spotify op je Mac).
        CommandMenu("Spotify") {
            Button("Play / Pause") { SpotifyController.shared.perform(.playPause) }.keyboardShortcut("p", modifiers: [.command, .option])
            Button("Next Track") { SpotifyController.shared.perform(.next) }.keyboardShortcut(.rightArrow, modifiers: [.command, .option])
            Button("Previous Track") { SpotifyController.shared.perform(.previous) }.keyboardShortcut(.leftArrow, modifiers: [.command, .option])
            Button("Volume Up") { let v = SpotifyController.shared.current?.volume ?? 50; SpotifyController.shared.perform(.setVolume, value: min(100, v + 10)) }
                .keyboardShortcut(.upArrow, modifiers: [.command, .option])
            Button("Volume Down") { let v = SpotifyController.shared.current?.volume ?? 50; SpotifyController.shared.perform(.setVolume, value: max(0, v - 10)) }
                .keyboardShortcut(.downArrow, modifiers: [.command, .option])
            Divider()
            Button("Shuffle On/Off") { SpotifyController.shared.perform(.toggleShuffle) }
            Button("Repeat On/Off") { SpotifyController.shared.perform(.toggleRepeat) }
            Divider()
            Menu("Sleep Timer") {
                ForEach([15, 30, 45, 60, 90], id: \.self) { m in Button("\(m) minutes") { SpotifyCoordinator.shared.startSleepTimer(minutes: m) } }
                Button("Off") { SpotifyCoordinator.shared.cancelSleepTimer() }
            }
            Button("Open Spotify") { SpotifyController.shared.perform(.launch) }
        }
    }
}
