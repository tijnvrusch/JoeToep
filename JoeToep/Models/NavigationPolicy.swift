import Foundation

struct NavigationPolicy {
    enum FilterReason: String, Equatable {
        case shorts = "Shorts"
        case posts = "posts and community pages"
        case premium = "Premium destinations"
    }

    enum Decision: Equatable {
        case allow
        case openExternally
        case block(FilterReason)
    }

    let settings: SettingsSnapshot

    func decision(for url: URL) -> Decision {
        guard let scheme = url.scheme?.lowercased() else { return .openExternally }
        if ["about", "blob", "data"].contains(scheme) { return .allow }
        guard ["http", "https"].contains(scheme) else { return .openExternally }

        let host = (url.host ?? "").lowercased()
        // V15: JoeToep is a full browser; other sites open in a tab unless turned off.
        guard Self.isAllowedWebHost(host) else { return settings.openWebLinksInApp ? .allow : .openExternally }

        guard Self.isYouTubeHost(host) else { return .allow }
        let path = url.path.lowercased()

        if settings.blockShortsNavigation, path.hasPrefix("/shorts/") {
            return .block(.shorts)
        }
        if settings.blockPostsNavigation,
           path.hasPrefix("/post/")
            || path.hasSuffix("/community")
            || path.contains("/community/")
            || path.hasSuffix("/posts")
            || path.contains("/posts/") {
            return .block(.posts)
        }
        if settings.blockPremiumDestinations,
           path.hasPrefix("/premium") || path.hasPrefix("/paid_memberships") || path.hasPrefix("/musicpremium") {
            return .block(.premium)
        }
        return .allow
    }

    static func isYouTubeHost(_ host: String) -> Bool {
        host == "youtube.com"
            || host.hasSuffix(".youtube.com")
            || host == "youtube-nocookie.com"
            || host.hasSuffix(".youtube-nocookie.com")
            || host == "youtu.be"
    }

    static func isPlaybackPage(_ url: URL?) -> Bool {
        guard let url, isYouTubeHost((url.host ?? "").lowercased()) else { return false }
        return url.path == "/watch" || ["/shorts/", "/live/", "/embed/"].contains { url.path.hasPrefix($0) }
    }

    static func isAllowedWebHost(_ host: String) -> Bool {
        isYouTubeHost(host)
            || host == "google.com"
            || host.hasSuffix(".google.com")
            || host == "googleusercontent.com"
            || host.hasSuffix(".googleusercontent.com")
            || host == "gstatic.com"
            || host.hasSuffix(".gstatic.com")
    }
}
