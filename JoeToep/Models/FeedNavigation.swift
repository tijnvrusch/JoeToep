import Foundation

/// Keep account feeds off the mobile-only routes that can render an empty shell.
/// Playback pages retain the user's selected presentation.
struct FeedNavigation {
    static func needsDesktop(_ url: URL, isPhone: Bool) -> Bool {
        guard NavigationPolicy.isYouTubeHost(url.host ?? "") else { return false }
        return url.path == "/feed/history" || (isPhone && ["/feed/you", "/feed/library"].contains(url.path))
    }
}
