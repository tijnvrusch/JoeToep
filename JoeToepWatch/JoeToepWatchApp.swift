import SwiftUI
import WatchKit

/// JoeToep voor Apple Watch — alleen de essentie: home-feed, zoeken, afspelen/bedienen.
/// De video speelt op je iPhone (of Mac/iPad met JoeToep open); de Watch is de afstandsbediening.
@main
struct JoeToepWatchApp: App {
    @WKApplicationDelegateAdaptor private var appDelegate: JoeToepWatchAppDelegate
    @StateObject private var store = WatchStore.shared
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onAppear { store.start() }
        }
    }
}

/// V22.2: de verbinding meteen bij het starten — ook bij een achtergrondstart (complicaties
/// verversen) zonder dat er een scherm verschijnt. `start()` is idempotent.
final class JoeToepWatchAppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() { WatchStore.shared.start() }
}
