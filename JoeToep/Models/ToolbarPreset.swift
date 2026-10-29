import Foundation

/// V19 — Snelle indelingen voor de menubalk. "Minimal" is de nieuwe, rustige standaard:
/// alleen de knoppen die je steeds gebruikt; al het andere zit in het ⋯-menu en blijft per knop
/// aan te zetten in Instellingen.
enum ToolbarPreset: String, CaseIterable, Identifiable, Sendable {
    case minimal, standard, everything
    var id: String { rawValue }
    var title: String {
        switch self {
        case .minimal: "Minimal (clean, recommended)"
        case .standard: "Standard"
        case .everything: "Everything"
        }
    }

    @MainActor func apply(to s: AppSettings) {
        let all = self == .everything, std = self != .minimal
        s.showNavigationControls = true
        s.showHomeButton = true
        s.showSubscriptionsButton = std
        s.showLibraryButton = std
        s.showHistoryButton = all
        s.showPlaylistButton = all
        s.showRefreshButton = std
        s.showBookmarkButton = all
        s.showQualityButton = std
        s.showAirPlayButton = all
        s.showPiPButton = true
        s.showCreatorTools = all
        s.showSpeedControl = true
        s.showDownloadButton = std
        s.showConnectionStatus = all
        s.showMoreMenu = true
        s.showSettingsButton = true
    }
}
