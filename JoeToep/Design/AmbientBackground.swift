import SwiftUI

struct AmbientBackground: View {
    var body: some View {
        // A background must never contribute a 460pt intrinsic width on a 390pt phone.
        Color(red: 0.035, green: 0.035, blue: 0.04)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}
