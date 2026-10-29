import SwiftUI

/// Afstandsbediening: titel, op welk apparaat, live voortgang, afspelen/pauzeren, spoelen,
/// snelheid, en "verder op…".
struct NowPlayingView: View {
    @EnvironmentObject private var store: WatchStore

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                let t = store.targetState
                Text(t?.title ?? (store.nowTitle.isEmpty ? "Nothing playing" : store.nowTitle))
                    .font(.footnote.weight(.semibold)).lineLimit(2).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                if let t {
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        if let pos = t.livePosition(at: ctx.date), let d = t.duration, d > 0 {
                            VStack(spacing: 1) {
                                ProgressView(value: min(pos, d), total: d).tint(.red)
                                HStack { Text(watchClock(pos)); Spacer(); Text("-" + watchClock(max(0, d - pos))) }
                                    .font(.system(size: 10).monospacedDigit()).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if store.state.devices.count > 1 || store.devices.count > 1 {
                    Picker("Play on", selection: $store.target) {
                        ForEach(store.state.devices.isEmpty ? store.devices.map { WatchDeviceState(id: $0.id, name: $0.name, kind: "iphone", isPhone: false, connected: true) } : store.state.devices.filter(\.connected)) {     // V22.2: geen offline apparaten
                            Label($0.name, systemImage: $0.symbol).tag($0.id)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .font(.caption2)
                    .frame(height: 30)
                } else {
                    Label(store.targetName, systemImage: t?.symbol ?? "iphone").font(.caption2).foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    round("gobackward.\(Int(store.skipSeconds))", "Back") { await store.seek(-store.skipSeconds) }
                    Button { Task { await store.toggle() } } label: {
                        Image(systemName: (t?.playing ?? store.playing) ? "pause.fill" : "play.fill")
                            .font(.title2).frame(width: 54, height: 54)
                            .background(Circle().fill(Color.red))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel((t?.playing ?? store.playing) ? "Pause" : "Play")
                    round("goforward.\(Int(store.skipSeconds))", "Forward") { await store.seek(store.skipSeconds) }
                }
                HStack(spacing: 10) {
                    small("minus") { await store.rate(-1) }
                    Text(rateText).font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(store.rate == 1 ? Color.secondary : Color.red).frame(minWidth: 34)
                    small("plus") { await store.rate(1) }
                }
                if let t, t.title != nil {
                    let others = store.state.devices.filter { $0.id != t.id && $0.connected }
                    if !others.isEmpty {
                        ForEach(others) { o in
                            Button { Task { await store.move(from: t.id, to: o.id) } } label: {
                                Label("Continue on \(o.name)", systemImage: o.symbol).font(.caption2).frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
                if let message = store.message { Text(message).font(.caption2).foregroundStyle(.orange).lineLimit(3) }
            }
            .padding(.horizontal, 4)
        }
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
