import SwiftUI

/// Afstandsbediening: titel, op welk apparaat, afspelen/pauzeren, ±10 s en snelheid.
struct NowPlayingView: View {
    @EnvironmentObject private var store: WatchStore
    var body: some View {
        VStack(spacing: 6) {
            Text(store.nowTitle.isEmpty ? "Nothing playing" : store.nowTitle)
                .font(.footnote.weight(.semibold)).lineLimit(2).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            if store.devices.count > 1 {
                Picker("Play on", selection: $store.target) {
                    ForEach(store.devices) { Text($0.name).tag($0.id) }
                }
                .pickerStyle(.navigationLink)
                .font(.caption2)
                .frame(height: 30)
            } else {
                Label(store.targetName, systemImage: "iphone").font(.caption2).foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                round("gobackward.10", "Back 10 seconds") { await store.seek(-10) }
                Button { Task { await store.toggle() } } label: {
                    Image(systemName: store.playing ? "pause.fill" : "play.fill")
                        .font(.title2).frame(width: 54, height: 54)
                        .background(Circle().fill(Color.red))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(store.playing ? "Pause" : "Play")
                round("goforward.10", "Forward 10 seconds") { await store.seek(10) }
            }
            HStack(spacing: 10) {
                small("minus") { await store.rate(-1) }
                Text(rateText).font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(store.rate == 1 ? Color.secondary : Color.red).frame(minWidth: 34)
                small("plus") { await store.rate(1) }
            }
            if let message = store.message { Text(message).font(.caption2).foregroundStyle(.orange).lineLimit(2) }
        }
        .padding(.horizontal, 4)
        .navigationTitle("Now Playing")
        .task { await store.refreshStatus() }
    }

    private var rateText: String { store.rate == store.rate.rounded() ? String(format: "%.0f×", store.rate) : String(format: "%g×", store.rate) }

    private func round(_ symbol: String, _ label: String, _ action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            Image(systemName: symbol).font(.body).frame(width: 40, height: 40)
                .background(Circle().fill(Color.white.opacity(0.12)))
        }
        .buttonStyle(.plain).accessibilityLabel(label)
    }
    private func small(_ symbol: String, _ action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            Image(systemName: symbol).font(.caption.weight(.bold)).frame(width: 30, height: 26)
                .background(Capsule().fill(Color.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }
}
