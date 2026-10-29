import WebKit

/// V17 — wist cookies, cache en alle andere websitegegevens van JoeToep.
/// `WKWebsiteDataStore.default()` is de gedeelde opslag van alle normale tabs.
/// `allWebsiteDataTypes()` = cookies, cache, localStorage, IndexedDB, service workers, …
@MainActor
enum PrivacyCleaner {
    /// Wist alles sinds 1 januari 1970 (dus: alles) en roept daarna `done` aan.
    static func clearAll(done: @escaping () -> Void = {}) {
        WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                                                modifiedSince: .distantPast, completionHandler: done)
    }
    /// "Wissen bij afsluiten": tijdens het afsluiten kunnen we niet op WebKit wachten (de app zou
    /// dan bevriezen). Daarom zetten we bij afsluiten een vlag, en wissen we bij de VOLGENDE start,
    /// voordat er een pagina laadt. Resultaat is hetzelfde: bij het openen is alles schoon.
    static func markForClearingOnQuit() {
        guard UserDefaults.standard.bool(forKey: "clearDataOnQuitV17") else { return }
        UserDefaults.standard.set(true, forKey: "pendingClearV17")
    }
    /// Bij het starten van de app: stond de vlag? Dan nu alles wissen en de vlag weghalen.
    static func clearPendingAtLaunch() {
        guard UserDefaults.standard.bool(forKey: "pendingClearV17") else { return }
        UserDefaults.standard.removeObject(forKey: "pendingClearV17")
        clearAll()
    }
}
