import SwiftUI

/// Exclusive gestures prevent a long press from also executing a normal toggle.
struct PiPButton: View {
    @ObservedObject var session: WebSession
    let size: CGFloat
    var iconSize: CGFloat = 17
    @Environment(\.joeToepTheme) private var theme
    var body: some View {
        Image(systemName: "pip")
            .themedIcon(theme, size: iconSize, active: session.isInPictureInPicture)
            .frame(width: size, height: max(size, 44)).contentShape(Rectangle())
            .gesture(LongPressGesture(minimumDuration: 0.3, maximumDistance: 18)
                .exclusively(before: TapGesture()).onEnded { value in
                    switch value {
                    case .first(true): session.resetPictureInPicture()
                    case .second: if !session.isPiPRequesting { session.togglePictureInPicture() }
                    default: break
                    }
                })
            .overlay { if session.isPiPRequesting { ProgressView().controlSize(.mini).allowsHitTesting(false) } }
            .accessibilityElement().accessibilityAddTraits(.isButton)
            .accessibilityLabel("Picture in Picture")
            .accessibilityHint("Hold for 0.3 seconds to reset Picture in Picture")
            .accessibilityAction { session.togglePictureInPicture() }
            .accessibilityAction(named: "Reset Picture in Picture") { session.resetPictureInPicture() }
            .accessibilityIdentifier("toolbar.pip")
            .help("Picture in Picture · hold 0.3s to reset")
    }
}
