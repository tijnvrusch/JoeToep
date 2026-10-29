import Foundation

struct SessionNotice: Identifiable, Equatable {
    enum Kind: Equatable {
        case information
        case success
        case warning
        case error
    }

    let id = UUID()
    let kind: Kind
    let title: String
    let message: String

    static func == (lhs: SessionNotice, rhs: SessionNotice) -> Bool {
        lhs.kind == rhs.kind && lhs.title == rhs.title && lhs.message == rhs.message
    }

    var symbolName: String {
        switch kind {
        case .information: "info.circle.fill"
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        }
    }
}

