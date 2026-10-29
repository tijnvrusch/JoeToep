import SwiftUI

struct OnboardingView: View {
    @ObservedObject var settings: AppSettings
    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 68)).foregroundStyle(Color.red)
                Text("JoeToep").font(.largeTitle.bold())
                Text("#yolo").font(.headline).foregroundStyle(.secondary)
                Text("More video. Less interface.")
                    .font(.title3.weight(.medium)).multilineTextAlignment(.center)
                VStack(alignment: .leading, spacing: 16) {
                    Label("One black bar, five direct destinations", systemImage: "rectangle.bottomthird.inset.filled")
                    Label("Automatic PiP requests and playback fallbacks", systemImage: "pip")
                    Label("Fill, pinch zoom and quick resolution selection", systemImage: "arrow.up.left.and.arrow.down.right")
                }.font(.subheadline)
                Text("Enable automatic PiP in your device settings. Apple and the video website decide when system PiP is available.")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button {
                    settings.acceptServiceNotice()
                } label: {
                    Text("Open JoeToep").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent).tint(.red)
                .accessibilityIdentifier("onboarding.continue")
                Text("Personal project · not affiliated with YouTube")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .padding(24).frame(maxWidth: 420)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
        }
        .background(AmbientBackground()).preferredColorScheme(.dark)
    }
}
