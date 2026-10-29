import Foundation

enum StartPage: String, CaseIterable, Codable, Identifiable, Sendable {
    case home
    case subscriptions
    case library
    case history
    case watchLater

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .subscriptions: "Subscriptions"
        case .library: "Library"
        case .history: "History"
        case .watchLater: "Watch later"
        }
    }

    var symbolName: String {
        switch self {
        case .home: "house"
        case .subscriptions: "rectangle.stack"
        case .library: "books.vertical"
        case .history: "clock.arrow.circlepath"
        case .watchLater: "bookmark"
        }
    }

    var url: URL {
        let rawURL: String
        switch self {
        case .home: rawURL = "https://m.youtube.com/"
        case .subscriptions: rawURL = "https://m.youtube.com/feed/subscriptions"
        case .library: rawURL = "https://www.youtube.com/feed/you"
        case .history: rawURL = "https://www.youtube.com/feed/history"
        case .watchLater: rawURL = "https://m.youtube.com/playlist?list=WL"
        }
        return URL(string: rawURL) ?? URL(fileURLWithPath: "/")
    }
}
