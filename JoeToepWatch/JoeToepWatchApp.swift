import SwiftUI

/// JoeToep voor Apple Watch — alleen de essentie: home-feed, zoeken, afspelen/bedienen.
/// De video speelt op je iPhone (of Mac/iPad met JoeToep open); de Watch is de afstandsbediening.
@main
struct JoeToepWatchApp: App {
    @StateObject private var store = WatchStore()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onAppear { store.start() }
        }
    }
}
