import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// V17.1 — JoeToep als standaardbrowser.
///
/// • Mac: JoeToep meldt zich (Info.plist › CFBundleURLTypes) aan als app die http/https-links en
///   HTML-bestanden kan openen. Met `setDefaultApplication` vraagt de app macOS om de standaard te
///   worden; macOS toont dan zelf een bevestiging ("JoeToep gebruiken of Safari houden?").
/// • iPhone/iPad: iOS laat alleen apps met Apple's speciale "browser-entitlement" als standaard
///   kiezen. Dat recht geeft Apple per app, niet aan gratis ontwikkelaarsaccounts. Daarom kan het
///   daar (nog) niet; de knop opent Instellingen zodat je ziet welke keuze iOS aanbiedt.
@MainActor
enum DefaultBrowser {
    /// V18 — omweg voor iPhone/iPad: links als `joetoep://…` openen JoeToep (via een Opdracht,
    /// de deelknop of een QR-code). Vorm: `joetoep://open?url=<https-link>`, of simpelweg
    /// `joetoep://www.youtube.com/watch?v=…` / `joetoeps://…` (dan wordt het https).
    static func webURL(fromCustom url: URL) -> URL? {
        guard url.scheme?.lowercased() == "joetoep" else { return nil }
        if let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let raw = parts.queryItems?.first(where: { $0.name == "url" })?.value,
           let target = URL(string: raw), ["http", "https"].contains(target.scheme?.lowercased() ?? "") { return target }
        let rest = url.absoluteString.dropFirst("joetoep://".count)
        if rest.hasPrefix("https://") || rest.hasPrefix("http://") { return URL(string: String(rest)) }
        guard !rest.isEmpty, !rest.hasPrefix("open") else { return nil }
        return URL(string: "https://" + rest)
    }

    /// Is JoeToep nu de standaardapp voor https-links? (alleen Mac kan dit uitlezen)
    static var isDefault: Bool {
        #if os(macOS)
        guard let url = URL(string: "https://example.com"),
              let app = NSWorkspace.shared.urlForApplication(toOpen: url) else { return false }
        return Bundle(url: app)?.bundleIdentifier == Bundle.main.bundleIdentifier
        #else
        return false
        #endif
    }
    /// Vraagt het systeem om JoeToep standaard te maken (Mac) of opent Instellingen (iOS).
    static func request(completion: @escaping (String) -> Void) {
        #if os(macOS)
        let app = Bundle.main.bundleURL
        NSWorkspace.shared.setDefaultApplication(at: app, toOpenURLsWithScheme: "http") { error in
            NSWorkspace.shared.setDefaultApplication(at: app, toOpenURLsWithScheme: "https") { error2 in
                DispatchQueue.main.async {
                    completion((error ?? error2).map { "macOS did not change it: \($0.localizedDescription)" }
                               ?? "Done: links now open in JoeToep.")
                }
            }
        }
        #else
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        completion("iOS only lets Apple-approved browser apps become the default. JoeToep is installed with a free developer account, so iOS does not offer it here.")
        #endif
    }
}
